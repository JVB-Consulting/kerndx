// =============================================================================
// Section 33 Setup: Knowledge Article Data for Data Category Tests
// =============================================================================
// Org: ${SF_SUBSCRIBER_ORG_ALIAS} (Knowledge-enabled, created with km-scratch-def.json)
// Prerequisites:
//   - kern managed package installed
//   - Knowledge settings deployed
//   - Data category groups KM_TestCategory and KM_TestRegion deployed and active
//
// Run:
//   sf apex run -o $SF_SUBSCRIBER_ORG_ALIAS -f release-testing/scripts/section-33-knowledge-setup.apex
// =============================================================================

List<Knowledge__kav> articles = new List<Knowledge__kav>();

articles.add(new Knowledge__kav(
	Title = 'KDX Test Alpha North',
	UrlName = 'kdx-test-alpha-north',
	Language = 'en_US',
	Summary = 'Test article categorised as Alpha and North'
));

articles.add(new Knowledge__kav(
	Title = 'KDX Test Alpha South',
	UrlName = 'kdx-test-alpha-south',
	Language = 'en_US',
	Summary = 'Test article categorised as Alpha and South'
));

articles.add(new Knowledge__kav(
	Title = 'KDX Test Beta North',
	UrlName = 'kdx-test-beta-north',
	Language = 'en_US',
	Summary = 'Test article categorised as Beta and North'
));

insert articles;

List<Knowledge__kav> inserted = [
	SELECT Id, KnowledgeArticleId, Title
	FROM Knowledge__kav
	WHERE Title LIKE 'KDX Test%'
	AND PublishStatus = 'Draft'
	AND Language = 'en_US'
];

for(Knowledge__kav article : inserted)
{
	KbManagement.PublishingService.publishArticle(article.KnowledgeArticleId, false);
	System.debug('33-SETUP: Published "' + article.Title + '" (KnowledgeArticleId: ' + article.KnowledgeArticleId + ')');
}

System.debug('33-SETUP: Inserted and published ' + inserted.size() + ' Knowledge articles');
System.debug('33-SETUP: Assign data categories via Knowledge tab before running section-33 tests');
System.debug('33-SETUP PASS: Knowledge test data created');
