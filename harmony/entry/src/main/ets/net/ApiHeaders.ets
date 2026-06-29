export class ApiHeaders {
  private static deviceUserAgent: string = '';

  static setDeviceUserAgent(ua: string): void {
    ApiHeaders.deviceUserAgent = ua || '';
  }

  static json(authHeader: string, token: string): Record<string, string> {
    const headers: Record<string, string> = {
      'Accept': 'application/json, text/plain, */*'
    };
    ApiHeaders.applyAuth(headers, authHeader, token);
    return headers;
  }

  static multipart(authHeader: string, token: string): Record<string, string> {
    const headers: Record<string, string> = {
      'Accept': 'application/json, text/plain, */*',
      'Content-Type': 'multipart/form-data'
    };
    ApiHeaders.applyAuth(headers, authHeader, token);
    return headers;
  }

  static download(authHeader: string, token: string): Record<string, string> {
    const headers: Record<string, string> = {
      'Accept': '*/*'
    };
    ApiHeaders.applyAuth(headers, authHeader, token);
    return headers;
  }

  static applyAuth(headers: Record<string, string>, authHeader: string, token: string): void {
    if (authHeader.length > 0) {
      headers['X-Custom-Auth'] = authHeader;
    }
    const ua = ApiHeaders.getDeviceUserAgent();
    if (ua.length > 0) {
      headers['X-Custom-Device-UA'] = ua;
    }
    if (token.length > 0) {
      headers['Cookie'] = 'token=' + token;
    }
  }

  private static getDeviceUserAgent(): string {
    return ApiHeaders.deviceUserAgent;
  }
}
