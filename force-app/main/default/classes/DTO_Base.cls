// SPDX-License-Identifier: BUSL-1.1
/**
 * @description A base Data Transfer Object (DTO) class for storing JSON content, providing utility
 * methods for serialization, deserialization, and transformation of DTOs. Supports
 * pretty-print formatting for JSON content.
 *
 * @see DTO_Base_TEST
 *
 * @author Jason van Beukering
 *
 * @group Data Transfer Objects
 *
 * @date February 2026, May 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * DTO_Base dto = new DTO_Base();
 * String json = dto.serialize();
 * dto.populate(recordId, new DTO_NameValues());
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
@JsonAccess(Serializable='always' Deserializable='always')
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
	 * @description Serializes the current DTO object to a JSON string. This method provides a
	 * string representation of the DTO for storage or transfer.
	 *
	 * @return A serialized JSON string representing the DTO.
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
	 * @description Deserializes a JSON string and populates a new instance of `DTO_Base` with
	 * the deserialized data, enabling conversion from JSON format back into a DTO.
	 *
	 * @param dtoString A JSON-formatted string that can be converted to a DTO.
	 *
	 * @return A `DTO_Base` instance populated with data from the provided JSON string.
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