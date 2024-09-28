class ValidationService {
  // 이메일 형식 검사 정규식
  static final RegExp _emailRegExp =
      RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

  // 이메일 형식 검사 메서드
  static bool isEmailValid(String email) {
    return _emailRegExp.hasMatch(email);
  }

  // 예시: 비밀번호 유효성 검사 (최소 6자 이상)
  static bool isPasswordValid(String password) {
    return password.length >= 6;
  }

  // 핸드폰 번호 유효성 검사 (11자리 숫자)
  static bool isPhoneValid(String phoneNumber) {
    final RegExp phoneRegExp = RegExp(r'^\d{11}$');
    return phoneRegExp.hasMatch(phoneNumber);
  }

  // 이름(별명) 유효성 검사, 한글만 최대 6자
  static bool isNameValid(String name) {
    final nameRegExp = RegExp(r'^[가-힣]{1,6}$');
    return nameRegExp.hasMatch(name);
  }
}
