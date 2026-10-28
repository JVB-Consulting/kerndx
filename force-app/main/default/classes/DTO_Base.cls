// SPDX-License-Identifier: BUSL-1.1
/**
 * @description An empty base class for Data Transfer Objects (DTOs). A DTO is a small class that holds the
 * fields you move in or out of your org. This class only declares the methods; on their own they do nothing:
 * serialize() returns an empty string, deserialize() returns the same instance, and populate() and transform()
 * change nothing. Your subclass overrides the methods it needs. For DTOs that convert to and from JSON,
 * extend DTO_JsonBase instead.
 *
 * @see DTO_Base_TEST
 *
 * @author Jason van Beukering
 *
 * @group Data Transfer Objects
 *
 * @date February 2026, October 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * public class DTO_AccountSummary extends DTO_Base
 * {
 *     public String accountName;
 *     public override void populate(Id recordId)
 *     {
 *         accountName = 'Name read for ' + recordId;
 *     }
 * }
 * DTO_AccountSummary summary = new DTO_AccountSummary();
 * summary.populate(recordId, new DTO_NameValues());
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
@JsonAccess(serializable='always' deserializable='always')
global inherited sharing virtual class DTO_Base
{
	/**
	 * @description Implements the equality checker of custom class, so can be used in maps and sets
	 *
	 * @param obj Object to be compared
	 *
	 * @return either True of False
	 */
	public Boolean equals(Object obj)
	{
		Boolean isEqual = false;

		if(obj instanceof DTO_Base)
		{
			DTO_Base passedObj = (DTO_Base)obj;

			String currentObjJson = serialize();
			String passedObjJson = passedObj.serialize();

			isEqual = currentObjJson == passedObjJson;
		}

		return isEqual;
	}

	/**
	 * @description Will return hashCode for this object used when searching by key in a map
	 *
	 * @return Number
	 */
	public Integer hashCode()
	{
		return serialize().hashCode();
	}

	/**
	 * @description Returns the DTO as a string. In this base class it returns an empty string;
	 * override it in your subclass, or extend DTO_JsonBase, to get JSON.
	 *
	 * @return An empty string in this base class.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String result = instance.serialize();
	 * ```
	 */
	global virtual String serialize()
	{
		return UTIL_String.EMPTY;
	}

	/**
	 * @description Turns a string back into a DTO. In this base class it ignores the string and
	 * returns the same instance; override it in your subclass, or extend DTO_JsonBase, to read JSON.
	 *
	 * @param dtoString The string to read. This base class does not read it.
	 *
	 * @return The same instance, unchanged, in this base class.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DTO_Base result = instance.deserialize('value');
	 * ```
	 */
	@SuppressWarnings('ApexUnusedDeclaration')
	global virtual DTO_Base deserialize(String dtoString)
	{
		return this;
	}

	/**
	 * @description Populates the current DTO instance using the specified triggering object ID.
	 * This method enables retrieval of relevant data using an ID parameter.
	 *
	 * @param recordId The ID of the object to retrieve data for population.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * instance.populate(recordId);
	 * ```
	 */
	@SuppressWarnings('ApexUnusedDeclaration,PMD.EmptyStatementBlock')
	global virtual void populate(Id recordId)
	{
	}

	/**
	 * @description Populates the current DTO instance using the specified triggering object ID and
	 * additional request parameters. Allows customized data retrieval and population.
	 *
	 * @param recordId The ID of the object to retrieve data for population.
	 * @param dtoRequestParameters A list of name values that can be used to change the query or the population of the request DTO
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * instance.populate(recordId, new DTO_NameValues());
	 * ```
	 */
	@SuppressWarnings('ApexUnusedDeclaration')
	global virtual void populate(Id recordId, DTO_NameValues dtoRequestParameters)
	{
		populate(recordId);
	}

	/**
	 * @description Transforms the current DTO using another DTO as input. This method allows
	 * flexibility for child classes to implement their own transformation logic.
	 *
	 * @param dtoBase The input DTO to transform from.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * instance.transform(new DTO_Base());
	 * ```
	 */
	@SuppressWarnings('ApexUnusedDeclaration,PMD.EmptyStatementBlock')
	global virtual void transform(DTO_Base dtoBase)
	{
	}
}