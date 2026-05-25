// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Deliberate violations of every KernDX PMD rule. Used to validate the scanner
 * ruleset catches all anti-patterns. Each method triggers exactly one rule.
 *
 * Expected violations:
 * - KernNoInlineSOQL (x4: inline SOQL, Database.query, Database.getQueryLocator, Database.getCursor)
 * - KernNoDirectDML (x4: insert statement, Database.insert, Database.merge, Database.emptyRecycleBin)
 * - KernNoSystemDebug (x2: violateSystemDebug + ViolateSchedulable.execute)
 * - KernNoRawHttp (x3: HttpRequest, Http, WebServiceCallout.invoke)
 * - KernUseSchedulerBase (x1: implements Schedulable)
 * - KernNoRawCache (x2: Cache.Org + Cache.Session)
 * - KernNoRawDescribe (x1: Schema.getGlobalDescribe)
 * - KernNoRawTypeForName (x1: Type.forName)
 * - KernNoRawEnqueueJob (x1: System.enqueueJob)
 * - KernNoRawSchedule (x1: System.schedule)
 * - KernNoRawEventPublish (x1: EventBus.publish)
 * - KernNoRawHttpMock (x1: implements HttpCalloutMock)
 * - KernNoRawRestContext (x2: RestContext.request + RestContext.response)
 * - KernNoRawCrypto (x1: Crypto.generateAesKey)
 * - KernNoRawEmail (x1: Messaging.sendEmail)
 * - KernNoRawFeatureManagement (x1: FeatureManagement.checkPermission)
 */
public with sharing class ScannerTestViolations
{
	/**
	 * @description Violates KernNoInlineSOQL — inline SOQL.
	 */
	public void violateInlineSoql()
	{
		List<Account> accounts =
		[
				SELECT Id,
						Name
				FROM Account
				LIMIT 1
		];
	}

	/**
	 * @description Violates KernNoInlineSOQL — Database.query().
	 */
	public void violateDatabaseQuery()
	{
		List<Account> accounts = Database.query('SELECT Id FROM Account');
	}

	/**
	 * @description Violates KernNoInlineSOQL — Database.getQueryLocator().
	 */
	public void violateDatabaseGetQueryLocator()
	{
		Database.QueryLocator locator = Database.getQueryLocator('SELECT Id FROM Account');
	}

	/**
	 * @description Violates KernNoInlineSOQL — Database.getCursor().
	 */
	public void violateDatabaseGetCursor()
	{
		Database.Cursor cursor = Database.getCursor('SELECT Id FROM Account');
	}

	/**
	 * @description Violates KernNoDirectDML — insert statement.
	 */
	public void violateDirectInsert()
	{
		Account account = new Account(Name = 'Test');
		insert Account;
	}

	/**
	 * @description Violates KernNoDirectDML — Database.insert().
	 */
	public void violateDatabaseInsert()
	{
		Account account = new Account(Name = 'Test');
		Database.insert(Account);
	}

	/**
	 * @description Violates KernNoDirectDML — Database.merge().
	 */
	public void violateDatabaseMerge()
	{
		Account master = new Account(Name = 'Master');
		Account duplicate = new Account(Name = 'Duplicate');
		Database.merge(master, duplicate);
	}

	/**
	 * @description Violates KernNoDirectDML — Database.emptyRecycleBin().
	 */
	public void violateDatabaseEmptyRecycleBin()
	{
		Database.emptyRecycleBin(new List<Id>());
	}

	/**
	 * @description Violates KernNoSystemDebug.
	 */
	public void violateSystemDebug()
	{
		System.debug('This should use LOG_Builder');
	}

	/**
	 * @description Violates KernNoRawHttp — new HttpRequest().
	 */
	public void violateRawHttpRequest()
	{
		HttpRequest request = new HttpRequest();
		Request.setMethod('GET');
	}

	/**
	 * @description Violates KernNoRawHttp — new Http().
	 */
	public void violateRawHttp()
	{
		Http client = new Http();
	}

	/**
	 * @description Violates KernNoRawHttp — WebServiceCallout.invoke().
	 */
	public void violateWebServiceCallout()
	{
		WebServiceCallout.invoke(null, null, null, null, null, null, null, null, null, null, null);
	}

	/**
	 * @description Violates KernNoRawCache — Cache.Org.
	 */
	public void violateRawOrgCache()
	{
		Cache.Org.put('key', 'value');
	}

	/**
	 * @description Violates KernNoRawCache — Cache.Session.
	 */
	public void violateRawSessionCache()
	{
		Object value = Cache.Session.get('key');
	}

	/**
	 * @description Violates KernNoRawDescribe — Schema.getGlobalDescribe().
	 */
	public void violateRawDescribe()
	{
		Map<String, SObjectType> types = Schema.getGlobalDescribe();
	}

	/**
	 * @description Violates KernNoRawTypeForName — Type.forName().
	 */
	public void violateRawTypeForName()
	{
		Type resolvedType = Type.forName('Account');
	}

	/**
	 * @description Violates KernNoRawEnqueueJob — System.enqueueJob().
	 */
	public void violateRawEnqueueJob()
	{
		System.enqueueJob(new ViolateSchedulable());
	}

	/**
	 * @description Violates KernNoRawSchedule — System.schedule().
	 */
	public void violateRawSchedule()
	{
		System.schedule('Test', '0 0 12 * * ?', new ViolateSchedulable());
	}

	/**
	 * @description Violates KernNoRawEventPublish — EventBus.publish().
	 */
	public void violateRawEventPublish()
	{
		EventBus.publish(new List<SObject>());
	}

	/**
	 * @description Violates KernNoRawRestContext — RestContext.request.
	 */
	public void violateRawRestContextRequest()
	{
		RestRequest request = RestContext.request;
	}

	/**
	 * @description Violates KernNoRawRestContext — RestContext.response.
	 */
	public void violateRawRestContextResponse()
	{
		RestContext.response = new RestResponse();
	}

	/**
	 * @description Violates KernNoRawCrypto — Crypto.generateAesKey().
	 */
	public void violateRawCrypto()
	{
		Blob key = Crypto.generateAesKey(256);
	}

	/**
	 * @description Violates KernNoRawEmail — Messaging.sendEmail().
	 */
	public void violateRawEmail()
	{
		Messaging.sendEmail(new List<Messaging.SingleEmailMessage>());
	}

	/**
	 * @description Violates KernNoRawFeatureManagement — FeatureManagement.checkPermission().
	 */
	public void violateRawFeatureManagement()
	{
		Boolean hasPermission = FeatureManagement.checkPermission('MyCustomPermission');
	}

	/**
	 * @description Violates KernUseSchedulerBase — implements Schedulable directly.
	 */
	public class ViolateSchedulable implements Schedulable
	{
		/**
		 * @description Schedulable execute.
		 *
		 * @param context
		 */
		public void execute(SchedulableContext context)
		{
			System.debug('Should extend SCHED_Base');
		}
	}

	/**
	 * @description Violates KernNoRawHttpMock — implements HttpCalloutMock directly.
	 */
	public class ViolateHttpMock implements HttpCalloutMock
	{
		/**
		 * @description Mock respond method.
		 *
		 * @param request
		 *
		 * @return
		 */
		public HttpResponse respond(HttpRequest request)
		{
			return new HttpResponse();
		}
	}
}
