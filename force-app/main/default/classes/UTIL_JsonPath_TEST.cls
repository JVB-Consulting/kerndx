// SPDX-License-Identifier: MIT
/**
 * MIT License
 *
 * Copyright (c) 2018 open-force
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

/**
 * @description Tests the behaviour of UTIL_JsonPath
 * adapted from [open-force](https://github.com/open-force/jsonparse)
 *
 * @see UTIL_JsonPath
 *
 * @author Jason van Beukering
 *
 * @group Utilities
 *
 * @date February 2026, May 2026
 */
@SuppressWarnings('PMD.CognitiveComplexity,PMD.CyclomaticComplexity,PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class UTIL_JsonPath_TEST
{
	// Some JSON samples from https://json.org/example.html
	private static final String SAMPLE1 = '{"menu":{"id":"file","value":"File","popup":{"menuitem":[{"value":"New","onclick":"CreateNewDoc()"},{"value":"Open",' +
			'"onclick":"OpenDoc()"},{"value":"Close","onclick":"CloseDoc()"}]}}}';
	private static final String SAMPLE2 = '{"widget":{"debug":"on","window":{"title":"SampleKonfabulatorWidget","name":"main_window","width":500,"height":500},' +
			'"image":{"src":"Images/Sun.png","name":"sun1","hOffset":250,"vOffset":250,"alignment":"center"},"text":{"data":"ClickHere","size":36,"style":"bold",' +
			'"name":"text1","hOffset":250,"vOffset":100,"alignment":"center","onMouseUp":"sun1.opacity=(sun1.opacity/100)*90;"}}}';
	private static final String SAMPLE3 = '[{"servlet-name":"cofaxCDS","servlet-class":"org.cofax.cds.CDSServlet","init-param":{"configGlossary:installationAt":' +
			'"Philadelphia,PA","configGlossary:adminEmail":"ksm@pobox.com","configGlossary:poweredBy":"Cofax","configGlossary:poweredByIcon":"/images/cofax.gif",' +
			'"configGlossary:staticPath":"/content/static","templateProcessorClass":"org.cofax.WysiwygTemplate","templateLoaderClass":' +
			'"org.cofax.FilesTemplateLoader","templatePath":"templates","templateOverridePath":"","defaultListTemplate":"listTemplate.htm","defaultFileTemplate":' +
			'"articleTemplate.htm","useJSP":false,"jspListTemplate":"listTemplate.jsp","jspFileTemplate":"articleTemplate.jsp","cachePackageTagsTrack":200,' +
			'"cachePackageTagsStore":200,"cachePackageTagsRefresh":60,"cacheTemplarack":100,"cacheTemplatesStore":50,"cacheTemplatesRefresh":15,' +
			'"cachePagesTrack":200,"cachePagesStore":100,"cachePagesRefresh":10,"cachePagesDirtyRead":10,"searchEngineListTemplate":"forSearchEnginesList.htm",' +
			'"searchEngineFileTemplate":"forSearchEngines.htm","searchEngineRobotsDb":"WEB-INF/robots.db","useDataStore":true,"dataStoreClass":' +
			'"org.cofax.SqlDataStore","redirectionClass":"org.cofax.SqlRedirection","dataStoreName":"cofax","dataStoreDriver":"com.microsoft.jdbc.sqlserver.' +
			'SQLServerDriver","dataStoreUrl":"jdbc:microsoft:sqlserver://LOCALHOST:1433;DatabaseName=goon","dataStoreUser":"sa","dataStorePasswor":' +
			'"dataStoreTestQuery","dataStoreTestQuery":"SETNOCOUNTON;selecttest=\'test\';","dataStoreLogFile":"/usr/local/tomcat/logs/datastore.log",' +
			'"dataStoreInitConns":10,"dataStoreMaxConns":100,"dataStoreConnUsageLimit":100,"dataStoreLogLevel":"debug","maxUrlLength":500}},{"servlet-name":' +
			'"cofaxEmail","servlet-class":"org.cofax.cds.EmailServlet","init-param":{"mailHost":"mail1","mailHostOverride":"mail2"}},{"servlet-name":"cofaxAdmin"' +
			',"servlet-class":"org.cofax.cds.AdminServlet"},{"servlet-name":"fileServlet","servlet-class":"org.cofax.cds.FileServlet"},{"servlet-name":' +
			'"cofaxTools","servlet-class":"org.cofax.cms.CofaxToolsServlet","init-param":{"templatePath":"toolstemplates/","log":1,"logLocation":"' +
			'/usr/local/tomcat/logs/CofaxTools.log","logMaxSize":"","dataLog":1,"dataLogLocation":"/usr/local/tomcat/logs/dataLog.log","dataLogMaxSize":"",' +
			'"removePageCache":"/content/admin/remove?cache=pages&id=","removeTemplateCache":"/content/admin/remove?cache=templates&id=","fileTransferFolder":' +
			'"/usr/local/tomcat/webapps/content/fileTransferFolder","lookInContext":1,"adminGroupID":4,"betaServer":true}}]';

	/**
	 * @description Tests parsing a raw JSON string value
	 *
	 * @see UTIL_JsonPath.getStringValue
	 */
	@IsTest
	private static void rawString()
	{
		UTIL_JsonPath parser = new UTIL_JsonPath('"HelloWorld"');
		Assert.isFalse(parser.isObject(), 'Expected parser not to be an object');
		Assert.isFalse(parser.isArray(), 'Expected parser not to be an array');
		Assert.areEqual('HelloWorld', parser.getStringValue(), 'Expected string value to be HelloWorld');
	}

	/**
	 * @description Tests parsing a raw JSON boolean false value
	 *
	 * @see UTIL_JsonPath.getBooleanValue
	 */
	@IsTest
	private static void rawBooleanFalse()
	{
		UTIL_JsonPath parser = new UTIL_JsonPath('false');
		Assert.isFalse(parser.isObject(), 'Expected parser not to be an object');
		Assert.isFalse(parser.isArray(), 'Expected parser not to be an array');
		Assert.isFalse(parser.getBooleanValue(), 'Expected boolean value to be false');
	}

	/**
	 * @description Tests parsing a raw JSON boolean true value
	 *
	 * @see UTIL_JsonPath.getBooleanValue
	 */
	@IsTest
	private static void rawBooleanTrue()
	{
		UTIL_JsonPath parser = new UTIL_JsonPath('true');
		Assert.isFalse(parser.isObject(), 'Expected parser not to be an object');
		Assert.isFalse(parser.isArray(), 'Expected parser not to be an array');
		Assert.isTrue(parser.getBooleanValue(), 'Expected boolean value to be true');
	}

	/**
	 * @description Tests parsing a raw JSON integer value
	 *
	 * @see UTIL_JsonPath.getIntegerValue
	 */
	@IsTest
	private static void rawInteger()
	{
		UTIL_JsonPath parser = new UTIL_JsonPath('42');
		Assert.isFalse(parser.isObject(), 'Expected parser not to be an object');
		Assert.isFalse(parser.isArray(), 'Expected parser not to be an array');
		Assert.areEqual(42, parser.getIntegerValue(), 'Expected integer value to be 42');
	}

	/**
	 * @description Tests parsing a raw JSON decimal value
	 *
	 * @see UTIL_JsonPath.getDecimalValue
	 */
	@IsTest
	private static void rawDecimal()
	{
		UTIL_JsonPath parser = new UTIL_JsonPath('17.22');
		Assert.isFalse(parser.isObject(), 'Expected parser not to be an object');
		Assert.isFalse(parser.isArray(), 'Expected parser not to be an array');
		Assert.areEqual(17.22, parser.getDecimalValue(), 'Expected decimal value to be 17.22');
	}

	/**
	 * @description Tests parsing a raw JSON number with scientific notation
	 *
	 * @see UTIL_JsonPath.getDecimalValue
	 */
	@IsTest
	private static void rawNumberWithENotation()
	{
		UTIL_JsonPath parser = new UTIL_JsonPath('1.2483e+2');
		Assert.isFalse(parser.isObject(), 'Expected parser not to be an object');
		Assert.isFalse(parser.isArray(), 'Expected parser not to be an array');
		Assert.areEqual(124.83, parser.getDecimalValue(), 'Expected decimal value to be 124.83');
	}

	/**
	 * @description Tests retrieving a value using a simple JSON path
	 *
	 * @see UTIL_JsonPath.get
	 */
	@IsTest
	private static void simpleGet()
	{
		UTIL_JsonPath parser = new UTIL_JsonPath(SAMPLE1);
		Assert.isTrue(parser.isObject(), 'Expected parser to be an object');
		Assert.isFalse(parser.isArray(), 'Expected parser not to be an array');
		Assert.areEqual('File', parser.get('menu.value').getStringValue(), 'Expected string value to be File');
	}

	/**
	 * @description Tests retrieving a value from an array using a JSON path
	 *
	 * @see UTIL_JsonPath.get
	 */
	@IsTest
	private static void arrayGet()
	{
		UTIL_JsonPath parser = new UTIL_JsonPath(SAMPLE1);
		Assert.isTrue(parser.isObject(), 'Expected parser to be an object');
		Assert.isFalse(parser.isArray(), 'Expected parser not to be an array');
		Assert.areEqual('OpenDoc()', parser.get('menu.popup.menuitem.[1].onclick').getStringValue(), 'Expected value to be OpenDoc()');
	}

	/**
	 * @description Tests retrieving a numeric value using a JSON path
	 *
	 * @see UTIL_JsonPath.get
	 */
	@IsTest
	private static void numberGet()
	{
		UTIL_JsonPath parser = new UTIL_JsonPath(SAMPLE2);
		Assert.isTrue(parser.isObject(), 'Expected parser to be an object');
		Assert.isFalse(parser.isArray(), 'Expected parser not to be an array');
		Assert.areEqual(100, parser.get('widget.text.vOffset').getIntegerValue(), 'Expected integer value to be 100');
	}

	/**
	 * @description Tests retrieving a value using a compound JSON path
	 *
	 * @see UTIL_JsonPath.get
	 */
	@IsTest
	private static void compoundGet()
	{
		UTIL_JsonPath parser = new UTIL_JsonPath(SAMPLE1);
		Assert.isTrue(parser.isObject(), 'Expected parser to be an object');
		Assert.isFalse(parser.isArray(), 'Expected parser not to be an array');
		Assert.areEqual('Close', parser.get('menu').get('popup.menuitem').get('[2].value').getStringValue(), 'Expected string value to be Close');
	}

	/**
	 * @description Tests exception handling for a missing key
	 *
	 * @see UTIL_JsonPath.get
	 */
	@IsTest
	private static void missingKeyException()
	{
		UTIL_JsonPath parser = new UTIL_JsonPath(SAMPLE2);

		try
		{
			parser.get('badKey');
			Assert.fail('Our key was invalid, should have seen an exception about that.');
		}
		catch(UTIL_JsonPath.MissingKeyException e)
		{
			Assert.areEqual('No match found for <badKey>: {widget}', e.getMessage(), 'Expected exception message for missing key');
		}
	}

	/**
	 * @description Tests exception handling when accessing a non-object node
	 *
	 * @see UTIL_JsonPath.get
	 */
	@IsTest
	private static void getNotAnObjectException()
	{
		UTIL_JsonPath parser = new UTIL_JsonPath(SAMPLE1);

		try
		{
			parser.get('menu.popup.menuitem.first');
			Assert.fail('Node is not an object, should have seen an exception about that.');
		}
		catch(UTIL_Exceptions.IllegalStateException e)
		{
			Assert.isTrue(e.getMessage().startsWith('The wrapped value is not a JSON object:'), 'Expected exception message for non-object node');
		}
	}

	/**
	 * @description Tests exception handling when accessing a non-array node as an array
	 *
	 * @see UTIL_JsonPath.get
	 */
	@IsTest
	private static void getNotAnArrayException()
	{
		UTIL_JsonPath parser = new UTIL_JsonPath(SAMPLE1);

		try
		{
			parser.get('menu.popup.[0]');
			Assert.fail('Node is not an array, should have seen an exception about that.');
		}
		catch(UTIL_Exceptions.IllegalStateException e)
		{
			Assert.isTrue(e.getMessage().startsWith('The wrapped value is not a JSON array:'), 'Expected exception message for non-array node');
		}
	}

	/**
	 * @description Tests that get throws ListException for an out-of-bounds array index
	 *
	 * @see UTIL_JsonPath.get
	 */
	@IsTest
	private static void getOutOfBoundsArrayIndex()
	{
		UTIL_JsonPath parser = new UTIL_JsonPath(SAMPLE3);

		try
		{
			parser.get('[99]');
			Assert.fail('Out-of-bounds array index should throw ListException');
		}
		catch(ListException e)
		{
			Assert.isTrue(e.getMessage().contains('out of bounds'), 'Expected out-of-bounds error message');
		}
	}

	/**
	 * @description Tests that findNode returns null when array notation is applied to a non-array node
	 *
	 * @see UTIL_JsonPath.findNode
	 */
	@IsTest
	private static void findNodeReturnsNullForArrayNotationOnNonArray()
	{
		UTIL_JsonPath parser = new UTIL_JsonPath(SAMPLE1);

		Assert.isNull(parser.findNode('menu.[0]'), 'Array notation on non-array should return null');
	}

	/**
	 * @description Tests that findNode returns null when key notation is applied to a non-object node
	 *
	 * @see UTIL_JsonPath.findNode
	 */
	@IsTest
	private static void findNodeReturnsNullForKeyOnNonObject()
	{
		UTIL_JsonPath parser = new UTIL_JsonPath(SAMPLE1);

		Assert.isNull(parser.findNode('menu.popup.menuitem.someKey'), 'Key on non-object should return null');
	}

	/**
	 * @description Tests checking the existence of a valid key path
	 *
	 * @see UTIL_JsonPath.exists
	 */
	@IsTest
	private static void existsGoodKey()
	{
		UTIL_JsonPath parser = new UTIL_JsonPath(SAMPLE1);

		Assert.isTrue(parser.exists('menu.popup.menuitem.[1].onclick'), 'Expected key path to exist');
	}

	/**
	 * @description Tests checking the existence of a path with an invalid intermediary key
	 *
	 * @see UTIL_JsonPath.exists
	 */
	@IsTest
	private static void existsNoIntermediaryKey()
	{
		UTIL_JsonPath parser = new UTIL_JsonPath(SAMPLE1);

		Assert.isFalse(parser.exists('menu.popup.menuitems.[1].onclick'), 'Expected key path not to exist');
	}

	/**
	 * @description Tests checking the existence of a non-existent key
	 *
	 * @see UTIL_JsonPath.exists
	 */
	@IsTest
	private static void existsNoKey()
	{
		UTIL_JsonPath parser = new UTIL_JsonPath(SAMPLE1);

		Assert.isFalse(parser.exists('menu.popup.menuitem.[1].onexplosion'), 'Expected key path not to exist');
	}

	/**
	 * @description Tests checking the existence of a valid array index
	 *
	 * @see UTIL_JsonPath.exists
	 */
	@IsTest
	private static void existsGoodIndex()
	{
		UTIL_JsonPath parser = new UTIL_JsonPath(SAMPLE3);

		Assert.isTrue(parser.exists('[1]'), 'Expected array index to exist');
	}

	/**
	 * @description Tests checking the existence of an invalid array index
	 *
	 * @see UTIL_JsonPath.exists
	 */
	@IsTest
	private static void existsBadIndex()
	{
		UTIL_JsonPath parser = new UTIL_JsonPath(SAMPLE3);

		Assert.isFalse(parser.exists('[7]'), 'Expected array index not to exist');
	}

	/**
	 * @description Tests retrieving boolean values from various JSON representations
	 *
	 * @see UTIL_JsonPath.getBooleanValue
	 */
	@IsTest
	private static void getBooleanValue()
	{
		UTIL_JsonPath parser = new UTIL_JsonPath('false');
		Assert.isFalse(parser.isObject(), 'Expected parser not to be an object');
		Assert.isFalse(parser.isArray(), 'Expected parser not to be an array');
		Assert.isFalse(parser.getBooleanValue(), 'Expected boolean value to be false');

		parser = new UTIL_JsonPath('"false"');
		Assert.isFalse(parser.isObject(), 'Expected parser not to be an object');
		Assert.isFalse(parser.isArray(), 'Expected parser not to be an array');
		Assert.isFalse(parser.getBooleanValue(), 'Expected boolean value to be false');

		parser = new UTIL_JsonPath('"FALSE"');
		Assert.isFalse(parser.isObject(), 'Expected parser not to be an object');
		Assert.isFalse(parser.isArray(), 'Expected parser not to be an array');
		Assert.isFalse(parser.getBooleanValue(), 'Expected boolean value to be false');

		parser = new UTIL_JsonPath('true');
		Assert.isFalse(parser.isObject(), 'Expected parser not to be an object');
		Assert.isFalse(parser.isArray(), 'Expected parser not to be an array');
		Assert.isTrue(parser.getBooleanValue(), 'Expected boolean value to be true');

		parser = new UTIL_JsonPath('"true"');
		Assert.isFalse(parser.isObject(), 'Expected parser not to be an object');
		Assert.isFalse(parser.isArray(), 'Expected parser not to be an array');
		Assert.isTrue(parser.getBooleanValue(), 'Expected boolean value to be true');

		parser = new UTIL_JsonPath('"TRUE"');
		Assert.isFalse(parser.isObject(), 'Expected parser not to be an object');
		Assert.isFalse(parser.isArray(), 'Expected parser not to be an array');
		Assert.isTrue(parser.getBooleanValue(), 'Expected boolean value to be true');
	}

	/**
	 * @description Tests retrieving Datetime values from JSON
	 *
	 * @see UTIL_JsonPath.getDatetimeValue
	 */
	@IsTest
	private static void getDatetimeValue()
	{
		UTIL_JsonPath parser = new UTIL_JsonPath('"2011-03-22T13:01:23"');
		Assert.areEqual(Datetime.newInstanceGmt(2011, 3, 22, 13, 1, 23), parser.getDatetimeValue(), 'Expected datetime to be 2011-03-22 13:01:23');

		parser = new UTIL_JsonPath('1538783039073');
		Assert.areEqual(Datetime.newInstanceGmt(2018, 10, 05, 23, 43, 59), parser.getDatetimeValue(), 'Expected datetime to be 2018-10-05 23:43:59');

		try
		{
			parser = new UTIL_JsonPath('[1,2,3]');
			parser.getDatetimeValue();
			Assert.fail('Node is not a valid Datetime, should have seen an exception about that.');
		}
		catch(TypeException e)
		{
			Assert.areEqual('Only Long and String values can be converted to a Datetime: [ 1, 2, 3 ]', e.getMessage(), 'Expected exception message for invalid datetime');
		}
	}

	/**
	 * @description Tests retrieving Date values from JSON
	 *
	 * @see UTIL_JsonPath.getDateValue
	 */
	@IsTest
	private static void getDateValue()
	{
		UTIL_JsonPath parser = new UTIL_JsonPath('"2011-03-22"');
		Assert.areEqual(Date.newInstance(2011, 3, 22), parser.getDateValue(), 'Expected date to be 2011-03-22');

		parser = new UTIL_JsonPath('1538783039073');
		Assert.areEqual(Date.newInstance(2018, 10, 05), parser.getDateValue(), 'Expected date to be 2018-10-05');

		try
		{
			parser = new UTIL_JsonPath('[1,2,3]');
			parser.getDateValue();
			Assert.fail('Node is not a valid Date, should have seen an exception about that.');
		}
		catch(TypeException e)
		{
			Assert.areEqual('Only Long and String values can be converted to a Date: [ 1, 2, 3 ]', e.getMessage(), 'Expected exception message for invalid date');
		}
	}

	/**
	 * @description Tests retrieving Decimal values from JSON
	 *
	 * @see UTIL_JsonPath.getDecimalValue
	 */
	@IsTest
	private static void getDecimalValue()
	{
		UTIL_JsonPath parser = new UTIL_JsonPath('12');
		Assert.areEqual(12.0, parser.getDecimalValue(), 'Expected decimal value to be 12.0');

		parser = new UTIL_JsonPath('12.5');
		Assert.areEqual(12.5, parser.getDecimalValue(), 'Expected decimal value to be 12.5');

		parser = new UTIL_JsonPath('"12.5"');
		Assert.areEqual(12.5, parser.getDecimalValue(), 'Expected decimal value to be 12.5');

		parser = new UTIL_JsonPath('1538783039073');
		Assert.areEqual(1538783039073.0, parser.getDecimalValue(), 'Expected decimal value to be 1538783039073.0');

		try
		{
			parser = new UTIL_JsonPath('[1,2,3]');
			parser.getDecimalValue();
			Assert.fail('Node is not a valid Decimal, should have seen an exception about that.');
		}
		catch(TypeException e)
		{
			Assert.areEqual('This value cannot be converted to a Decimal: [ 1, 2, 3 ]', e.getMessage(), 'Expected exception message for invalid decimal');
		}
	}

	/**
	 * @description Tests retrieving Salesforce Id values from JSON
	 *
	 * @see UTIL_JsonPath.getIdValue
	 */
	@IsTest
	private static void getIdValue()
	{
		Foobar__c record = TST_Factory.insertFoobar();

		UTIL_JsonPath parser = new UTIL_JsonPath('"' + String.valueOf(record.Id) + '"');
		Assert.areEqual(record.Id, parser.getIdValue(), 'Expected Id value to match inserted record Id');

		try
		{
			parser = new UTIL_JsonPath('[1,2,3]');
			parser.getIdValue();
			Assert.fail('Node is not a valid Id, should have seen an exception about that.');
		}
		catch(TypeException e)
		{
			Assert.areEqual('This value cannot be converted to an Id: [ 1, 2, 3 ]', e.getMessage(), 'Expected exception message for invalid Id');
		}
	}

	/**
	 * @description Tests retrieving Integer values from JSON
	 *
	 * @see UTIL_JsonPath.getIntegerValue
	 */
	@IsTest
	private static void getIntegerValue()
	{
		UTIL_JsonPath parser = new UTIL_JsonPath('12');
		Assert.areEqual(12, parser.getIntegerValue(), 'Expected integer value to be 12');

		parser = new UTIL_JsonPath('"12"');
		Assert.areEqual(12, parser.getIntegerValue(), 'Expected integer value to be 12');

		parser = new UTIL_JsonPath('12.5');
		Assert.areEqual(12, parser.getIntegerValue(), 'Expected integer value to be 12');

		parser = new UTIL_JsonPath('1538783039073');
		Assert.areEqual(1184747105, parser.getIntegerValue(), 'Expected integer value to be 1184747105'); // integer gets truncated

		try
		{
			parser = new UTIL_JsonPath('[1,2,3]');
			parser.getIntegerValue();
			Assert.fail('Node is not a valid Integer, should have seen an exception about that.');
		}
		catch(TypeException e)
		{
			Assert.areEqual('This value cannot be converted to an Integer: [ 1, 2, 3 ]', e.getMessage(), 'Expected exception message for invalid integer');
		}
	}

	/**
	 * @description Tests retrieving String values from JSON
	 *
	 * @see Util_JsonPath.getStringValue
	 */
	@IsTest
	private static void getStringValue()
	{
		UTIL_JsonPath parser = new UTIL_JsonPath('"HelloWorld"');
		Assert.areEqual('HelloWorld', parser.getStringValue(), 'Expected string value to be HelloWorld');

		parser = new UTIL_JsonPath('true');
		Assert.areEqual('true', parser.getStringValue(), 'Expected string value to be true');

		parser = new UTIL_JsonPath('null');
		Assert.isNull(parser.getStringValue(), 'Expected string value to be null');

		parser = new UTIL_JsonPath('12.5');
		Assert.areEqual('12.5', parser.getStringValue(), 'Expected string value to be 12.5');

		try
		{
			parser = new UTIL_JsonPath('{}');
			parser.getStringValue();
			Assert.fail('Node is not a valid String, should have seen an exception about that.');
		}
		catch(TypeException e)
		{
			Assert.areEqual('Objects and arrays are not Strings: { }', e.getMessage(), 'Expected exception message for invalid string');
		}

		try
		{
			parser = new UTIL_JsonPath('[]');
			parser.getStringValue();
			Assert.fail('Node is not a valid String, should have seen an exception about that.');
		}
		catch(TypeException e)
		{
			Assert.areEqual('Objects and arrays are not Strings: [ ]', e.getMessage(), 'Expected exception message for invalid string');
		}
	}

}