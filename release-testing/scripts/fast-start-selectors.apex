// Fast Start - Selectors: Tier 1 anonymous Apex examples
// Run in Developer Console > Debug > Open Execute Anonymous Window
// Requires at least one Account record. If none, insert one first:
//   insert new Account(Name = 'Quick Test', Industry = 'Technology', AnnualRevenue = 500000);

// -----------------------------------------------------------------------
// Example 1: QRY_Builder one-off query (no selector class needed)
// -----------------------------------------------------------------------
List<Account> accounts = kern.QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<SObjectField>{ Account.Name, Account.Industry })
	.withLimit(3)
	.toList();

System.debug('--- Example 1: first 3 Accounts ---');
for(Account account : accounts)
{
	System.debug(account.Name + ' -- ' + account.Industry);
}

// -----------------------------------------------------------------------
// Example 2: Condition + ordering
// -----------------------------------------------------------------------
List<Account> techAccounts = kern.QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<SObjectField>{ Account.Name, Account.Industry })
	.condition(Account.Industry).equals('Technology')
	.orderBy(Account.Name).ascending()
	.withLimit(5)
	.toList();

System.debug('--- Example 2: Technology accounts (max 5) ---');
System.debug('Found: ' + techAccounts.size());
for(Account account : techAccounts)
{
	System.debug('  ' + account.Name);
}

// -----------------------------------------------------------------------
// Example 3: Exists check (most efficient — no records loaded into memory)
// -----------------------------------------------------------------------
Boolean hasTech = kern.QRY_Builder.selectFrom(Account.SObjectType)
	.condition(Account.Industry).equals('Technology')
	.exists();
System.debug('--- Example 3: Technology accounts exist? ' + hasTech + ' ---');

// -----------------------------------------------------------------------
// Example 4: Aggregate — revenue by industry
// -----------------------------------------------------------------------
List<kern.QRY_Builder.AggregateRow> revenueRows = kern.QRY_Builder.selectFrom(Account.SObjectType)
	.fields(new List<SObjectField>{ Account.Industry })
	.groupBy(Account.Industry)
	.sum(Account.AnnualRevenue)
	.toAggregateList();

System.debug('--- Example 4: Revenue by industry ---');
for(kern.QRY_Builder.AggregateRow row : revenueRows)
{
	String industry = row.getString('Industry');
	Decimal revenue = row.getDecimal('sum_AnnualRevenue');
	System.debug('  ' + industry + ': ' + revenue);
}

System.debug('--- Done. Open App Launcher > Kern to see logged activity. ---');
