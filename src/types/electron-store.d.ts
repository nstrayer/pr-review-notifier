declare module 'electron-store' {
  export default class Store<T extends Record<string, any>> {
    constructor(options?: any);
    get<K extends keyof T>(key: K, defaultValue?: T[K]): T[K];
    set<K extends keyof T>(key: K, value: T[K]): void;
    delete(key: string): void;
    clear(): void;
    has(key: string): boolean;
    size: number;
    store: T;
    path: string;
  }
}