// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Guided setup modal for creating a Class Type Resolver Apex class.
 * Presents generated code with copy and download actions.
 *
 * @author Jason van Beukering
 *
 * @date April 2026, July 2026
 */
import LightningModal from 'lightning/modal';
import {copyToClipBoard} from 'c/utilitySystem';
import MODAL_TITLE from '@salesforce/label/c.ClassTypeResolverModal_Title';
import MODAL_PURPOSE from '@salesforce/label/c.ClassTypeResolverModal_Purpose';
import CLASS_NAME_LABEL from '@salesforce/label/c.ClassTypeResolverModal_ClassNameLabel';
import CLASS_NAME_PLACEHOLDER from '@salesforce/label/c.ClassTypeResolverModal_ClassNamePlaceholder';
import CLASS_NAME_PATTERN_ERROR from '@salesforce/label/c.ClassTypeResolverModal_ClassNamePatternError';
import CLASS_NAME_REQUIRED_ERROR from '@salesforce/label/c.ClassTypeResolverModal_ClassNameRequiredError';
import SETUP_STEPS_HEADING from '@salesforce/label/c.ClassTypeResolverModal_SetupStepsHeading';
import SETUP_STEPS_ALT_TEXT from '@salesforce/label/c.ClassTypeResolverModal_SetupStepsAltText';
import SETUP_STEP_1 from '@salesforce/label/c.ClassTypeResolverModal_SetupStep1';
import SETUP_STEP_2 from '@salesforce/label/c.ClassTypeResolverModal_SetupStep2';
import SETUP_STEP_3_TEMPLATE from '@salesforce/label/c.ClassTypeResolverModal_SetupStep3';
import SETUP_STEP_4 from '@salesforce/label/c.ClassTypeResolverModal_SetupStep4';
import RESOLVER_TAB_LABEL from '@salesforce/label/c.ClassTypeResolverModal_ResolverTabLabel';
import TEST_TAB_LABEL from '@salesforce/label/c.ClassTypeResolverModal_TestTabLabel';
import CODE_LANGUAGE_LABEL from '@salesforce/label/c.ClassTypeResolverModal_CodeLanguageLabel';
import COPY_RESOLVER_ALT_TEXT from '@salesforce/label/c.ClassTypeResolverModal_CopyResolverAltText';
import DOWNLOAD_RESOLVER_ALT_TEXT from '@salesforce/label/c.ClassTypeResolverModal_DownloadResolverAltText';
import COPY_TEST_ALT_TEXT from '@salesforce/label/c.ClassTypeResolverModal_CopyTestAltText';
import DOWNLOAD_TEST_ALT_TEXT from '@salesforce/label/c.ClassTypeResolverModal_DownloadTestAltText';
import CANCEL_LABEL from '@salesforce/label/c.ClassTypeResolverModal_Cancel';
import DONE_LABEL from '@salesforce/label/c.ClassTypeResolverModal_Done';
import COPY_FAILED from '@salesforce/label/c.ClassTypeResolverModal_CopyFailed';

const ICON_COPY = 'utility:copy_to_clipboard';
const ICON_CHECK = 'utility:check';
const COPY_RESET_DELAY = 1500;
const DEFAULT_CLASS_NAME = 'ACME_ClassTypeResolver';

export default class ClassTypeResolverSetupModal extends LightningModal
{
	resolverClassName = DEFAULT_CLASS_NAME;
	resolverCopyIcon = ICON_COPY;
	testCopyIcon = ICON_COPY;
	copyErrorMessage = null;

	labels = {
		title: MODAL_TITLE,
		purpose: MODAL_PURPOSE,
		classNameLabel: CLASS_NAME_LABEL,
		classNamePlaceholder: CLASS_NAME_PLACEHOLDER,
		classNamePatternError: CLASS_NAME_PATTERN_ERROR,
		classNameRequiredError: CLASS_NAME_REQUIRED_ERROR,
		setupStepsHeading: SETUP_STEPS_HEADING,
		setupStepsAltText: SETUP_STEPS_ALT_TEXT,
		setupStep1: SETUP_STEP_1,
		setupStep2: SETUP_STEP_2,
		setupStep4: SETUP_STEP_4,
		resolverTabLabel: RESOLVER_TAB_LABEL,
		testTabLabel: TEST_TAB_LABEL,
		codeLanguageLabel: CODE_LANGUAGE_LABEL,
		copyResolverAltText: COPY_RESOLVER_ALT_TEXT,
		downloadResolverAltText: DOWNLOAD_RESOLVER_ALT_TEXT,
		copyTestAltText: COPY_TEST_ALT_TEXT,
		downloadTestAltText: DOWNLOAD_TEST_ALT_TEXT,
		cancelLabel: CANCEL_LABEL,
		doneLabel: DONE_LABEL
	};

	get setupStep3()
	{
		return SETUP_STEP_3_TEMPLATE.replace('{0}', this.resolverClassName);
	}

	get resolverClassCode()
	{
		const name = this.resolverClassName;
		return `@SuppressWarnings('PMD.AvoidGlobalModifier')
global with sharing class ${name} extends kern.UTIL_TypeResolver.BaseClassResolver
{
\tpublic override Type resolveType(String className)
\t{
\t\treturn getTypeForClassName(className) ?? (Type)nextResolver?.resolveType(className);
\t}

\tprivate static Type getTypeForClassName(String className)
\t{
\t\tType classType;

\t\tif(String.isNotBlank(className))
\t\t{
\t\t\tString namespace = kern.UTIL_System.getNamespacePrefix(kern.UTIL_System.getClassNamespace(className), '.');

\t\t\tclassType = Type.forName(namespace, className);
\t\t\tclassType = classType == null && String.isNotBlank(namespace) ? Type.forName('', className) : classType;
\t\t}

\t\treturn classType;
\t}
}`;
	}

	get testClassCode()
	{
		const name = this.resolverClassName;
		return `@SuppressWarnings('PMD.ApexUnitTestClassShouldHaveRunAs')
@IsTest(SeeAllData=false IsParallel=true)
private class ${name}_TEST
{
\t@IsTest
\tprivate static void shouldResolveLocalClass()
\t{
\t\t${name} resolver = new ${name}();

\t\tType result = resolver.resolveType(${name}.class.getName());

\t\tAssert.isNotNull(result, 'Should resolve a local class');
\t}

\t@IsTest
\tprivate static void shouldResolveNestedClass()
\t{
\t\t${name} resolver = new ${name}();

\t\tType result = resolver.resolveType(kern.UTIL_TypeResolver.BaseClassResolver.class.getName());

\t\tAssert.isNotNull(result, 'Should resolve a nested class');
\t}

\t@IsTest
\tprivate static void shouldReturnNullWhenClassNotFound()
\t{
\t\t${name} resolver = new ${name}();

\t\tType result = resolver.resolveType('NonExistentClassName');

\t\tAssert.isNull(result, 'Should return null when class not found and no next resolver');
\t}

\t@IsTest
\tprivate static void shouldReturnNullWhenClassNameBlank()
\t{
\t\t${name} resolver = new ${name}();

\t\tType result = resolver.resolveType('');

\t\tAssert.isNull(result, 'Should return null for blank class name');
\t}
}`;
	}

	handleClassNameChange(event)
	{
		this.resolverClassName = event.detail.value;
	}

	/**
	 * @description Copies the generated resolver class to the clipboard, flipping the button icon
	 * to a check only once the copy actually happened. A failed copy (Clipboard API and its
	 * temporary-input fallback both failing) keeps the copy icon and reports the failure inline,
	 * so the admin can retry, select the code manually, or use the download action instead.
	 */
	async handleCopyResolver()
	{
		this.copyErrorMessage = null;
		try
		{
			await copyToClipBoard(this.resolverClassCode);
			this.resetCopyIcon('resolverCopyIcon');
		}
		catch
		{
			// copyToClipBoard already logged the failure; an in-modal message beats a toast the overlay would swallow.
			this.copyErrorMessage = COPY_FAILED;
		}
	}

	/**
	 * @description Copies the generated test class to the clipboard, flipping the button icon
	 * to a check only once the copy actually happened. A failed copy (Clipboard API and its
	 * temporary-input fallback both failing) keeps the copy icon and reports the failure inline,
	 * so the admin can retry, select the code manually, or use the download action instead.
	 */
	async handleCopyTest()
	{
		this.copyErrorMessage = null;
		try
		{
			await copyToClipBoard(this.testClassCode);
			this.resetCopyIcon('testCopyIcon');
		}
		catch
		{
			// copyToClipBoard already logged the failure; an in-modal message beats a toast the overlay would swallow.
			this.copyErrorMessage = COPY_FAILED;
		}
	}

	handleDownloadResolver()
	{
		this.downloadFile(`${this.resolverClassName}.cls`, this.resolverClassCode);
	}

	handleDownloadTest()
	{
		this.downloadFile(`${this.resolverClassName}_TEST.cls`, this.testClassCode);
	}

	handleCancel()
	{
		this.close('cancel');
	}

	handleConfirm()
	{
		this.close('confirmed');
	}

	downloadFile(filename, content)
	{
		const blob = new Blob([content], {type: 'application/octet-stream'});
		const url = URL.createObjectURL(blob);
		const anchor = document.createElement('a');
		anchor.href = url;
		anchor.download = filename;
		anchor.style.display = 'none';
		document.body.appendChild(anchor);
		anchor.click();
		document.body.removeChild(anchor);
		URL.revokeObjectURL(url);
	}

	resetCopyIcon(property)
	{
		this[property] = ICON_CHECK;
		clearTimeout(this[`_${property}Timeout`]);
		// eslint-disable-next-line @lwc/lwc/no-async-operation -- deliberate delay to reset copy icon
		this[`_${property}Timeout`] = setTimeout(() =>
		{
			this[property] = ICON_COPY;
		}, COPY_RESET_DELAY);
	}
}