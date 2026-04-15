import Foundation

enum VerificationCodeDetector {
    // Matches: keyword followed by 4-8 digit code
    // e.g. "验证码：123456", "code: 8888", "OTP 123456"
    private static let codePattern = try! NSRegularExpression(
        pattern: #"(?i)(验证码|verification|verify|code|OTP|PIN|密码|口令|captcha)[：:\s]*(\d{4,8})"#
    )

    // Fallback: standalone 4-8 digit number
    private static let digitPattern = try! NSRegularExpression(
        pattern: #"\b(\d{4,8})\b"#
    )

    private static let keywords: [String] = [
        "验证码", "动态密码", "短信码", "密码", "口令",
        "verification", "verify code", "otp", "pin码",
        "security code", "confirmation code", "captcha",
    ]

    static func isVerificationCode(title: String, message: String) -> Bool {
        let combined = (title + " " + message).lowercased()
        for keyword in keywords {
            if combined.contains(keyword.lowercased()) {
                return true
            }
        }
        let range = NSRange(combined.startIndex..., in: combined)
        return codePattern.firstMatch(in: combined, range: range) != nil
    }

    static func extractCode(title: String, message: String) -> String? {
        let combined = title + " " + message
        let range = NSRange(combined.startIndex..., in: combined)

        // Try keyword+code pattern first
        if let match = codePattern.firstMatch(in: combined, range: range),
           match.numberOfRanges > 2,
           let codeRange = Range(match.range(at: 2), in: combined) {
            return String(combined[codeRange])
        }

        // Fallback to standalone digit pattern
        if let match = digitPattern.firstMatch(in: combined, range: range),
           match.numberOfRanges > 1,
           let codeRange = Range(match.range(at: 1), in: combined) {
            return String(combined[codeRange])
        }

        return nil
    }
}
