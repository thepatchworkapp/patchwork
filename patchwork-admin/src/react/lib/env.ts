export function getEnv(key: string): string | undefined {
  return ((import.meta as any).env as Record<string, string | undefined>)?.[key];
}

export function requireEnv(key: string): string {
  const value = getEnv(key);
  if (!value) {
    throw new Error(`${key} is not set`);
  }
  return value;
}

