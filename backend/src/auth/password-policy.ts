// Shared across every DTO that accepts a new password (register,
// change-password, reset-password) so the rule and its message can't drift
// between them. Requires at least one lowercase letter, one uppercase
// letter, one digit, and one symbol — combined with @MinLength(8)/
// @MaxLength(72) on the field itself (72 because bcrypt silently ignores
// bytes beyond that, so a longer password wouldn't actually add strength,
// just create a confusing "your password is longer than what's checked" gap).
export const PASSWORD_REGEX =
  /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^a-zA-Z0-9]).*$/;

export const PASSWORD_POLICY_MESSAGE =
  'Password must include at least one lowercase letter, one uppercase letter, one number, and one symbol';
