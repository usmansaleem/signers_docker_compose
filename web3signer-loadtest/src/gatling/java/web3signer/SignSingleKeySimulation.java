package web3signer;

import static io.gatling.javaapi.core.CoreDsl.*;
import static io.gatling.javaapi.http.HttpDsl.*;

import com.fasterxml.jackson.databind.ObjectMapper;
import io.gatling.javaapi.core.*;
import io.gatling.javaapi.http.*;
import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.*;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.stream.Collectors;
import java.util.stream.Stream;

public class SignSingleKeySimulation extends Simulation {

  // Read endpoint from -Dweb3signer.endpoint (or default to http://localhost:9000)
  private static final String BASE_URL =
      System.getProperty("web3signer.endpoint", "http://localhost:9000");

  // Fetch all public keys once at startup
  private static final String[] ALL_KEYS = fetchPublicKeys();

  private static String[] fetchPublicKeys() {
    try {
      HttpClient client = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(5)).build();

      HttpRequest request =
          HttpRequest.newBuilder()
              .uri(URI.create(BASE_URL + "/api/v1/eth2/publicKeys"))
              .header("Accept", "application/json")
              .GET()
              .build();

      HttpResponse<String> response = client.send(request, HttpResponse.BodyHandlers.ofString());

      if (response.statusCode() != 200) {
        throw new RuntimeException(
            "Failed to fetch publicKeys (status=" + response.statusCode() + ")");
      }

      ObjectMapper mapper = new ObjectMapper();
      return mapper.readValue(response.body(), String[].class);

    } catch (IOException | InterruptedException e) {
      throw new RuntimeException("Error fetching /publicKeys from " + BASE_URL, e);
    }
  }

  // Build a listFeeder from ALL_KEYS (List of Map<String,Object> where key="publicKey")
  private static final List<Map<String, Object>> addressList =
      Stream.of(ALL_KEYS)
          .map(k -> Collections.<String, Object>singletonMap("publicKey", k))
          .collect(Collectors.toList());

  // Shared AtomicInteger for slot
  private static final AtomicInteger slotCounter = new AtomicInteger(0);

  // Iterator that always returns {"slot" -> next slotCounter value}
  private static final Iterator<Map<String, Object>> slotFeeder =
      Stream.<Map<String, Object>>generate(
              () -> Collections.singletonMap("slot", slotCounter.getAndIncrement()))
          .iterator();

  // HTTP protocol: always send/accept JSON
  private static final HttpProtocolBuilder httpProtocol =
      http.baseUrl(BASE_URL).acceptHeader("application/json").contentTypeHeader("application/json");

  // Scenario: pick one random key + one slot, then POST
  private static final ScenarioBuilder scn =
      scenario("SignOneRandomKeyPerUser")
          .feed(listFeeder(addressList).random()) // picks a random "publicKey"
          .feed(slotFeeder) // picks an incremented "slot"
          .exec(
              http("POST /api/v1/eth2/sign – #{publicKey}")
                  .post("/api/v1/eth2/sign/#{publicKey}")
                  .body(
                      StringBody(
                          """
                                          {
                                            "type": "block",
                                            "fork_info": {
                                              "fork": {
                                                "previous_version": "0x00000001",
                                                "current_version": "0x00000001",
                                                "epoch": "0"
                                              },
                                              "genesis_validators_root": "0x270d43e74ce340de4bca2b1936beca0f4f5408d9e78aec4850920baf659d5b69"
                                            },
                                            "block": {
                                              "slot": "#{slot}",
                                              "proposer_index": "5",
                                              "parent_root": "0xb2eedb01adbd02c828d5eec09b4c70cbba12ffffba525ebf48aca33028e8ad89",
                                              "state_root": "0x2b530d6262576277f1cc0dbe341fd919f9f8c5c92fc9140dff6db4ef34edea0d",
                                              "body": {
                                                "randao_reveal": "0xa686652aed2617da83adebb8a0eceea24bb0d2ccec9cd691a902087f90db16aa5c7b03172a35e874e07e3b60c5b2435c0586b72b08dfe5aee0ed6e5a2922b956aa88ad0235b36dfaa4d2255dfeb7bed60578d982061a72c7549becab19b3c12f",
                                                "eth1_data": {
                                                  "deposit_root": "0x6a0f9d6cb0868daa22c365563bb113b05f7568ef9ee65fdfeb49a319eaf708cf",
                                                  "deposit_count": "8",
                                                  "block_hash": "0x4242424242424242424242424242424242424242424242424242424242424242"
                                                },
                                                "graffiti": "0x74656b752f76302e31322e31302d6465762d6338316361363235000000000000",
                                                "proposer_slashings": [],
                                                "attester_slashings": [],
                                                "attestations": [],
                                                "deposits": [],
                                                "voluntary_exits": []
                                              }
                                            }
                                          }
                                          """))
                  .asJson()
                  .check(status().is(200)));

  // Injection: constant rate of 10 users per second for 5 minutes
  {
    setUp(scn.injectOpen(constantUsersPerSec(10).during(Duration.ofMinutes(5))))
        .protocols(httpProtocol);
  }
}
