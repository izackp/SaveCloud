//
//  File.swift
//  
//
//  Created by Isaac Paul on 5/14/24.
//

import Foundation
import Plot

/// Component used to render input controls using the `<input>` element.
public struct PasswordInput: InputComponent {
    /// The type of input to render. See `HTMLInputType` for more info.
    public let type: HTMLInputType = .password
    /// The rendered element's name. Maps to the `name` attribute.
    public var name: String?
    /// The rendered element's value. Maps to the `value` attribute.
    public var value: String?
    /// Whether the input element should be considered required.
    public var isRequired: Bool
    /// Any placeholder to render within the input element.
    public var placeholder: String?
    /// Minimum password length
    public var minLength: Int?
    /// Password validation regex
    public var pattern: String?
    /// Error message to display if password fails validation
    public var errorMsg: String?
    public var isAutoFocused = false

    @EnvironmentValue(.isAutoCompleteEnabled) private var isAutoCompleteEnabled

    /// Create a new input component instance.
    /// - parameters:
    ///   - type: The type of input to render. See `HTMLInputType` for more info.
    ///   - name: The rendered element's name. Maps to the `name` attribute.
    ///   - value: The rendered element's value. Maps to the `value` attribute.
    ///   - isRequired: Whether the input element should be considered required.
    ///   - placeholder: Any placeholder to render within the input element.
    ///   - minLength: Minimum password length
    ///   - pattern: Password validation regex
    ///   - errorMsg: Error message to display if password fails validation
    public init(name: String? = "password",
                value: String? = nil,
                isRequired: Bool = true,
                placeholder: String? = nil,
                minLength:Int? = 8,
                pattern:String? = "(?=.*\\d)(?=.*[a-z])(?=.*[A-Z]).{8,}",
                errorMsg:String? = "Must contain at least one number and one uppercase and lowercase letter, and at least 8 or more characters") {
        self.name = name
        self.value = value
        self.isRequired = isRequired
        self.placeholder = placeholder
        self.minLength = minLength
        self.pattern = pattern
        self.errorMsg = errorMsg
    }

    public var body: Component {
        Node.input(
            .type(type),
            .unwrap(name, Attribute.name),
            .unwrap(value, Attribute.value),
            .required(isRequired),
            .unwrap(placeholder, Attribute.placeholder),
            .autofocus(isAutoFocused),
            .unwrap(isAutoCompleteEnabled, Attribute.autocomplete),
            .unwrap(minLength, Attribute.minLength),
            .unwrap(pattern, Attribute.pattern),
            .unwrap(errorMsg, Attribute.title)
        )
    }
}


public extension Attribute where Context: HTMLContext {
    /// Assign an ID to the current element.
    /// - parameter id: The ID to assign.
    static func minLength(_ minLength: Int) -> Attribute {
        Attribute(name: "minlength", value: "\(minLength)")
    }
    
    /// Assign an ID to the current element.
    /// - parameter id: The ID to assign.
    static func pattern(_ pattern: String) -> Attribute {
        Attribute(name: "pattern", value: pattern)
    }

}
/*
 required
          minlength="8"
          pattern="(?=.*\d)(?=.*[a-z])(?=.*[A-Z]).{8,}"
          title="Must contain at least one number and one uppercase and lowercase letter, and at least 8 or more characters">
 */
