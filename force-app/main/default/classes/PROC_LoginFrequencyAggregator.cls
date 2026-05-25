// SPDX-License-Identifier: BUSL-1.1
/**
 * @description Processor that aggregates LoginHistory into per-user, per-month LoginFrequency__c records
 * tracking total login count and unique login day count. Designed for use with the adaptive async framework
 * via UTIL_AsynchronousJobLauncher, which automatically selects between Queueable and Batch Apex based on
 * data volume. Cross-chunk user splits are handled safely — each chunk either creates or increments the same
 * LoginFrequency__c record via the CompositeKey__c external ID.
 *
 * @see SCHED_ProcessLoginHistory
 * @see PROC_LoginFrequencyAggregator_TEST
 *
 * @author Jason van Beukering
 *
 * @group Bulk DML
 *
 * @date February 2026, May 2026
 */
public inherited sharing class PROC_LoginFrequencyAggregator implements IF_Async.Processable, IF_Async.Finishable
{
	/**
	 * @description The ScheduleSetting__c record name used for watermark tracking.
	 */
	public static final String SETTING_NAME = PROC_LoginFrequencyAggregator.class.getName();

	/**
	 * @description Separator used in composite keys (userId_yyyy-MM).
	 */
	@TestVisible
	private static final String UNDERSCORE = '_';

	/**
	 * @description The timestamp captured at job start, used to advance the watermark only after
	 * all chunks complete successfully.
	 */
	private final Datetime targetTimestamp;

	/**
	 * @description Constructs a processor with the given target timestamp for watermark advancement.
	 *
	 * @param targetTimestamp The timestamp to set as the new watermark after successful completion
	 */
	public PROC_LoginFrequencyAggregator(Datetime targetTimestamp)
	{
		this.targetTimestamp = targetTimestamp;
	}

	/**
	 * @description Converts LoginHistory records to DTOs and aggregates them into LoginFrequency__c records.
	 *
	 * @param items The list of LoginHistory records to process
	 */
	public void execute(List<Object> items)
	{
		try
		{
			generateAndStoreLoginFrequencies(convertToDto(items));
		}
		catch(Exception error)
		{
			LOG_Builder.build().error(error).at('PROC_LoginFrequencyAggregator.execute').emit();
			throw error;
		}
	}

	/**
	 * @description Advances the LastSuccessfulRunTime__c watermark after all chunks complete successfully.
	 *
	 * @param context The BatchableContext providing job details
	 */
	public void finish(Database.BatchableContext context)
	{
		ScheduleSetting__c setting = SEL_ScheduleSetting.getScheduleSetting(SETTING_NAME) ?? new ScheduleSetting__c(Name = SETTING_NAME);
		setting.LastSuccessfulRunTime__c = targetTimestamp;

		DML_Transaction unitOfWork = new DML_Transaction();
		unitOfWork.setAccessLevel(AccessLevel.SYSTEM_MODE);
		unitOfWork.doSave(setting);
		unitOfWork.commitWork();
	}

	/**
	 * @description Aggregates DTO login histories into LoginFrequency__c records and commits them.
	 *
	 * @param dtoLoginHistories A list of items to process
	 */
	@TestVisible
	private static void generateAndStoreLoginFrequencies(List<DTO_LoginHistory> dtoLoginHistories)
	{
		if(dtoLoginHistories == null || dtoLoginHistories.isEmpty())
		{
			return;
		}

		Date previousLoginDate;
		Integer totalCount;
		Integer uniqueCount;
		List<LoginFrequency__c> recordsToCreate = new List<LoginFrequency__c>();
		List<LoginFrequency__c> recordsToUpdate = new List<LoginFrequency__c>();
		Map<String, Integer> totalCountsMap = new Map<String, Integer>();
		Map<String, Integer> uniqueCountsMap = new Map<String, Integer>();
		Map<String, DTO_LoginHistory> compositeKeyToDto = new Map<String, DTO_LoginHistory>();
		Set<String> concatenatedStrings = new Set<String>();
		String previousConcatenatedString;

		for(DTO_LoginHistory currentLoginHistory : dtoLoginHistories)
		{
			String currentConcatenatedString = currentLoginHistory.userId + UNDERSCORE + currentLoginHistory.loginTime.formatGmt('yyyy-MM');
			concatenatedStrings.add(currentConcatenatedString);
			compositeKeyToDto.put(currentConcatenatedString, currentLoginHistory);

			if(previousConcatenatedString != currentConcatenatedString)
			{
				if(String.isNotBlank(previousConcatenatedString))
				{
					uniqueCountsMap.put(previousConcatenatedString, uniqueCount);
					totalCountsMap.put(previousConcatenatedString, totalCount);
				}

				previousConcatenatedString = currentConcatenatedString;
				previousLoginDate = null;
				uniqueCount = 0;
				totalCount = 0;
			}

			totalCount++;

			Date currentLoginDate = currentLoginHistory.loginTime.dateGmt();

			if(previousLoginDate != currentLoginDate)
			{
				previousLoginDate = currentLoginDate;
				uniqueCount++;
			}
		}

		uniqueCountsMap.put(previousConcatenatedString, uniqueCount);
		totalCountsMap.put(previousConcatenatedString, totalCount);

		List<LoginFrequency__c> relatedLoginFrequencyRecords = new SEL_LoginFrequency().findByUserIdAndLoginMonth(concatenatedStrings);
		Map<String, List<LoginFrequency__c>> userIdWithLoginMonthToRecordMap =
				UTIL_SObject.groupByStringKey(relatedLoginFrequencyRecords, SEL_LoginFrequency.FIELD_USERID_WITH_LOGIN_YEAR_AND_MONTH);

		for(String userIdAndLoginMonth : concatenatedStrings)
		{
			if(userIdWithLoginMonthToRecordMap.get(userIdAndLoginMonth) != null)
			{
				LoginFrequency__c recordToUpdate = (LoginFrequency__c)userIdWithLoginMonthToRecordMap.get(userIdAndLoginMonth)[0];

				recordToUpdate.TotalLoginCount__c = recordToUpdate.TotalLoginCount__c + totalCountsMap.get(userIdAndLoginMonth);
				recordToUpdate.UniqueLoginCount__c = recordToUpdate.UniqueLoginCount__c + uniqueCountsMap.get(userIdAndLoginMonth);

				recordsToUpdate.add(recordToUpdate);
			}
			else
			{
				DTO_LoginHistory representativeDto = compositeKeyToDto.get(userIdAndLoginMonth);
				Date loginDateGmt = representativeDto.loginTime.dateGmt();
				LoginFrequency__c recordToCreate = new LoginFrequency__c();

				recordToCreate.LoginMonth__c = loginDateGmt.month();
				recordToCreate.LoginYear__c = loginDateGmt.year();
				recordToCreate.TotalLoginCount__c = totalCountsMap.get(userIdAndLoginMonth);
				recordToCreate.UniqueLoginCount__c = uniqueCountsMap.get(userIdAndLoginMonth);
				recordToCreate.CompositeKey__c = userIdAndLoginMonth;
				recordToCreate.User__c = representativeDto.userId;

				recordsToCreate.add(recordToCreate);
			}
		}

		DML_Transaction unitOfWork = new DML_Transaction();
		unitOfWork.setAccessLevel(AccessLevel.SYSTEM_MODE);

		unitOfWork.doInsert(recordsToCreate);
		unitOfWork.doUpdate(recordsToUpdate);

		unitOfWork.commitWork();
	}

	/**
	 * @description Converts List of LoginHistory to List of DTO_LoginHistory. Accepts List of Object because the
	 * adaptive async framework's cloneItems returns List of Object, which cannot be directly cast to List of
	 * LoginHistory. LoginHistory records cannot be created in test context, so this conversion enables testable
	 * aggregation logic via DTO_LoginHistory.
	 *
	 * @param items List of LoginHistory records (as Objects) to be converted
	 *
	 * @return List of converted DTOs
	 */
	private static List<DTO_LoginHistory> convertToDto(List<Object> items)
	{
		List<DTO_LoginHistory> dtoLoginHistories = new List<DTO_LoginHistory>();

		for(Object item : items)
		{
			LoginHistory loginHistory = (LoginHistory)item;
			DTO_LoginHistory dtoLoginHistory = new DTO_LoginHistory();

			dtoLoginHistory.loginTime = loginHistory.LoginTime;
			dtoLoginHistory.userId = loginHistory.UserId;

			dtoLoginHistories.add(dtoLoginHistory);
		}

		return dtoLoginHistories;
	}

	/**
	 * @description DTO representing a single LoginHistory record for aggregation.
	 */
	public class DTO_LoginHistory
	{
		/**
		 * @description The user who logged in.
		 */
		public Id userId;

		/**
		 * @description The timestamp of the login event.
		 */
		public Datetime loginTime;
	}
}