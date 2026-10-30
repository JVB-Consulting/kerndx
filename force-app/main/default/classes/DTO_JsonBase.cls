// SPDX-License-Identifier: Apache-2.0
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
 * @date February 2026, October 2026
 *
 * @since 1.0
 *
 * @example
 * ```apex
 * @JsonAccess(serializable='always' deserializable='always')
 * public class DTO_Invoice extends DTO_JsonBase
 * {
 *     public String invoiceId;
 *     public String status;
 *     protected override Type getObjectType()
 *     {
 *         return DTO_Invoice.class;
 *     }
 * }
 * ```
 */
@SuppressWarnings('PMD.AvoidGlobalModifier')
@JsonAccess(serializable='always' deserializable='always')
global inherited sharing virtual class DTO_JsonBase extends DTO_Base
{
	/**
	 * @description Returns the type of the current DTO. It is used when JSON is turned back into an instance of your class.
	 * By default the package looks up your class by its name. It can find the class only when the class is global, or when you
	 * have registered a type resolver (a class that tells the framework where to find the Apex classes in your namespace).
	 * If neither is true, override this method in your DTO and return its type.
	 *
	 * @return The class type of the DTO.
	 *
	 * @throws IllegalArgumentException if the package cannot find your class by its name and you did not override this method
	 *
	 * @since 1.0
	 *
	 * @example
	 * ```apex
	 * public class DTO_Invoice extends DTO_JsonBase
	 * {
	 *     protected override Type getObjectType()
	 *     {
	 *         return DTO_Invoice.class;
	 *     }
	 * }
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