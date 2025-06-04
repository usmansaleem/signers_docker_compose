package web3signer;

import static io.gatling.javaapi.core.CoreDsl.*;
import static io.gatling.javaapi.http.HttpDsl.*;

import io.gatling.javaapi.core.*;
import io.gatling.javaapi.http.*;

public class HealthCheckSimulation extends Simulation {
  // Read endpoint from -Dweb3signer.endpoint (or default to http://localhost:9000)
  private static final String BASE_URL =
      System.getProperty("web3signer.endpoint", "http://localhost:9000");

  // 2) HTTP config: all requests are relative to BASE_URL
  private static final HttpProtocolBuilder httpProtocol =
      http.baseUrl(BASE_URL).acceptHeader("application/json").contentTypeHeader("application/json");

  // 3) One simple scenario: call GET /healthcheck, expect 200
  private static final ScenarioBuilder scn =
      scenario("HealthCheck")
          .exec(
              http("Get /healthcheck")
                  .get("/healthcheck")
                  .check(status().is(200))) // b) Step 2: GET /api/v1/eth2/publicKeys
          .exec(
              http("GET /publicKeys")
                  .get("/api/v1/eth2/publicKeys")
                  .check(
                      status().is(200),
                      // save the entire JSON array into session as a List<String>
                      jmesPath("[*]").ofList().saveAs("publicKeys")))
          // c) (Optional) Print out how many keys we got
          .exec(
              session -> {
                // Retrieve the List<String> from session
                java.util.List<String> keys = session.getList("publicKeys");
                System.out.println("→ Retrieved " + keys.size());
                return session;
              });

  // 4) Inject exactly one user, immediately
  {
    setUp(scn.injectOpen(atOnceUsers(1))).protocols(httpProtocol);
  }
}
