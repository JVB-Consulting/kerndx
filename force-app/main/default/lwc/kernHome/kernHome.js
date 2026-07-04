// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Kern developer control room. Displays health check banner and launch cards
 * for API Test Harness, Streaming Event Monitor, Chain Monitor, Data Masking Advisor, and
 * Log Console.
 *
 * @author Jason van Beukering
 *
 * @date April 2026, July 2026
 */
import {ComponentBuilder} from 'c/componentBuilder';
import ADMINISTRATION_TOOLS_HEADING from '@salesforce/label/c.KernHome_AdministrationToolsHeading';
import TOOL_OPEN_BUTTON from '@salesforce/label/c.KernHome_ToolOpenButton';
import API_TEST_HARNESS_TITLE from '@salesforce/label/c.KernHome_ApiTestHarness_Title';
import API_TEST_HARNESS_DESCRIPTION from '@salesforce/label/c.KernHome_ApiTestHarness_Description';
import STREAMING_MONITOR_TITLE from '@salesforce/label/c.KernHome_StreamingMonitor_Title';
import STREAMING_MONITOR_DESCRIPTION from '@salesforce/label/c.KernHome_StreamingMonitor_Description';
import CHAIN_MONITOR_TITLE from '@salesforce/label/c.KernHome_ChainMonitor_Title';
import CHAIN_MONITOR_DESCRIPTION from '@salesforce/label/c.KernHome_ChainMonitor_Description';
import DATA_MASKING_ADVISOR_TITLE from '@salesforce/label/c.KernHome_DataMaskingAdvisor_Title';
import DATA_MASKING_ADVISOR_DESCRIPTION from '@salesforce/label/c.KernHome_DataMaskingAdvisor_Description';
import LOG_CONSOLE_TITLE from '@salesforce/label/c.KernHome_LogConsole_Title';
import LOG_CONSOLE_DESCRIPTION from '@salesforce/label/c.KernHome_LogConsole_Description';

export default class KernHome extends ComponentBuilder('navigation')
{
	labels = {
		administrationToolsHeading: ADMINISTRATION_TOOLS_HEADING
	};

	tools = [
		{
			key: 'apiTestHarness',
			iconName: 'custom:custom63',
			title: API_TEST_HARNESS_TITLE,
			description: API_TEST_HARNESS_DESCRIPTION,
			buttonLabel: TOOL_OPEN_BUTTON,
			launchTarget: 'ApiTestHarness'
		},
		{
			key: 'streamingMonitor',
			iconName: 'custom:custom30',
			title: STREAMING_MONITOR_TITLE,
			description: STREAMING_MONITOR_DESCRIPTION,
			buttonLabel: TOOL_OPEN_BUTTON,
			launchTarget: 'StreamingEventMonitor'
		},
		{
			key: 'chainMonitor',
			iconName: 'custom:custom57',
			title: CHAIN_MONITOR_TITLE,
			description: CHAIN_MONITOR_DESCRIPTION,
			buttonLabel: TOOL_OPEN_BUTTON,
			launchTarget: 'ChainMonitor'
		},
		{
			key: 'dataMaskingAdvisor',
			iconName: 'custom:custom91',
			title: DATA_MASKING_ADVISOR_TITLE,
			description: DATA_MASKING_ADVISOR_DESCRIPTION,
			buttonLabel: TOOL_OPEN_BUTTON,
			launchTarget: 'DataMaskingAdvisor'
		},
		{
			key: 'logConsole', iconName: 'custom:custom7', title: LOG_CONSOLE_TITLE, description: LOG_CONSOLE_DESCRIPTION, buttonLabel: TOOL_OPEN_BUTTON, launchTarget: 'LogConsole'
		}
	];

	handleLaunch(event)
	{
		const key = event.currentTarget.dataset.key;
		const tool = this.tools.find((candidate) => candidate.key === key);

		this.navigate({
			type: 'standard__navItemPage', attributes: {apiName: tool.launchTarget}
		});
	}
}