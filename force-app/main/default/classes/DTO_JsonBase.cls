// SPDX-License-Identifier: BUSL-1.1
/**
 * @description A Data Transfer Object (DTO) base class for JSON serialization and deserialization,
 * providing a framework for transforming JSON data into structured objects and vice versa.
 * Inherited by other DTO classes that require JSON handling capabilities.
 *
 * @see DTO_JsonBase_TEST
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
 * @JsonAccess(Serializable='always' Deserializable='always')
 * public class DTO_Invoice extends DTO_JsonBase
 * {
 *     public String invoiceId;
 *     public String status;
 * }
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
@JsonAccess(Serializable='always' Deserializable='always')
global inherited sharing virtual class DTO_JsonBase extends DTO_Base
{
	/**
	 * @description Retrieves the type of the current DTO, used when deserializing JSON data back into an instance of the specific class.
	 * Implementing this method in descendant classes is required only if the class is private; to properly deserialize.
	 *
	 * @return The class type of the DTO.
	 *
	 * @throws IllegalArgumentException if the current class name can't be resolved to a Type (due to the class not being publicly visible)
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * Type result = instance.getObjectType();
	 * ```
	 */
	global protected virtual Type getObjectType()
	{
		String className = UTIL_System.getRuntimeTypeName(this);

		try
		{
			Type dtoType = UTIL_System.getTypeForClassName(className);
			return dtoType;
		}
		catch(Exception error)
		{
			String errorMessage = error.getMessage();
			errorMessage += UTIL_String.CRLF + 'To deserialize this DTO you must implement the virtual method "getObjectType()", or make the DTO class global';
			error.setMessage(errorMessage);

			throw error;
		}
	}

	/**
	 * @description Deserializes a JSON string into an instance of the current DTO class. Uses the
	 * `getObjectType` method to identify the appropriate class for deserialization.
	 * The returned instance is populated with values from the provided JSON string.
	 *
	 * @param dtoString A JSON string representing the serialized data for the DTO.
	 *
	 * @return A deserialized DTO instance populated with values from the JSON string.
	 *
	 * @see DTO_JsonBase.getObjectType
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * DTO_Base result = instance.deserialize('value');
	 * ```
	 */
	global override virtual DTO_Base deserialize(String dtoString)
	{
		//This line is to ensure base code is covered
		DTO_Base dtoBase = super.deserialize(dtoString);
		dtoBase = (DTO_Base)JSON.deserialize(dtoString, getObjectType());
		return dtoBase;
	}
	/**
	 * @description Serializes the current DTO instance into a JSON string, omitting null values
	 * to create a compact JSON representation. Useful for sending structured data
	 * over web services in a lightweight format.
	 *
	 * @return A JSON string representation of the current DTO, excluding null values.
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * String result = instance.serialize();
	 * ```
	 */
	global override virtual String serialize()
	{
		//This line is to ensure base code is covered
		String jsonString = super.serialize();
		return jsonString + JSON.serializePretty(this, true);
	}
}