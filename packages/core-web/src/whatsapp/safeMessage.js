const secretPatterns = [
  /\b(pin|otp|one[- ]time password|code secret|verification code)\b/i,
  /(?<!\d)\d{4,8}(?!\d)/,
];

export function isSafeMessage(text) {
  return typeof text === "string" && text.trim().length > 0 &&
    !secretPatterns.some((pattern) => pattern.test(text));
}

export function buildWaMeUrl(phoneE164Digits, text) {
  if (!/^\d{8,15}$/.test(phoneE164Digits)) throw new TypeError("invalid_phone");
  if (!isSafeMessage(text)) throw new Error("unsafe_message_content");
  return `https://wa.me/${phoneE164Digits}?text=${encodeURIComponent(text)}`;
}
