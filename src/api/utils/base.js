export const btoa = (string) => Buffer.from(string, 'utf-8').toString('base64')
export const atob = (b_string) => Buffer.from(b_string, 'base64').toString('utf-8')