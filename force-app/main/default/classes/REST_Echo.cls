// SPDX-License-Identifier: BUSL-1.1
/**
 * @description REST Endpoint wrapper class for the inbound echo test service.
 * This class serves as a RESTFUL endpoint that listens for POST requests to the `/echo/*` URL mapping.
 * The `echo` method processes incoming requests by invoking the relevant service for echo testing.
 * It is designed to handle simple test interactions, often used for verifying the inbound communication
 * functionality of an API or system integration.
 *
 * @see API_Echo_TEST
 *
 * @author Jason van Beukering
 *
 * @group Web Services
 *
 * @date February 2026, May 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * HttpRequest request = new HttpRequest();
 * request.setEndpoint(URL.getOrgDomainUrl().toExternalForm() + '/services/apexrest/echo');
 * request.setMethod('POST');
 * request.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
 * request.setHeader('Content-Type', 'application/json');
 * request.setBody('{"message":"Hello, Echo!"}');
 * HttpResponse response = new Http().send(request);
 * Assert.areEqual(200, response.getStatusCode());
 * Assert.areEqual('{"message":"Hello, Echo!"}', response.getBody());
 * ```
 */
@RestResource(UrlMapping='/echo/*')
global inherited sharing class REST_Echo
{
	/**
	 * @description Handles the POST method for the echo service (inbound).
	 * This method processes incoming POST requests to the `/echo/*` endpoint.
	 * It is typically used for echoing data back or testing the APIs response to inbound requests.
	 * In this implementation, it calls the `processInboundService` method from the `API_Dispatcher`
	 * to trigger further handling of the request based on the `API_Echo` class configuration.
	 *
	 * @since 1.0
	 *
	 * @example
	 * Sample HTTP Request:
	 * ```apex
	 * POST /services/apexrest/echo
	 * Content-Type: application/json
	 * {"message": "Hello, Echo!"}
	 * ```
	 * Expected Response:
	 * ```apex
	 * {"message": "Hello, Echo!"}
	 * ```
	 * Apex (called automatically by the framework):
	 * ```apex
	 * REST_Echo.echo();
	 * ```
	 */
	@HttpPost
	global static void echo()
	{
		API_Dispatcher.processInboundService(API_Echo.class.getName());
	}
}