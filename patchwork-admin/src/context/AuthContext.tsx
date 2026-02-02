import { createContext, useContext, useState, useEffect, type ReactNode } from 'react';

interface AuthContextType {
  isAuthenticated: boolean;
  isLoading: boolean;
  email: string | null;
  login: (email: string, otp: string) => Promise<void>;
  logout: () => void;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [isLoading, setIsLoading] = useState(true);
  const [email, setEmail] = useState<string | null>(null);

  useEffect(() => {
    const storedAuth = localStorage.getItem('adminAuth');
    const storedEmail = localStorage.getItem('adminEmail');
    
    if (storedAuth === 'true' && storedEmail) {
      setIsAuthenticated(true);
      setEmail(storedEmail);
    }
    
    setIsLoading(false);
  }, []);

  const login = async (loginEmail: string, otp: string) => {
    setIsLoading(true);
    try {
      const convexUrl = import.meta.env.VITE_CONVEX_URL;
      if (!convexUrl) throw new Error('VITE_CONVEX_URL is not set');
      const convexSiteUrl = convexUrl.includes('.convex.site') 
        ? convexUrl 
        : convexUrl.replace('.convex.cloud', '.convex.site');
      
      const response = await fetch(`${convexSiteUrl}/admin/verify-otp`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: loginEmail, otp }),
      });

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({}));
        throw new Error(errorData.error || 'Verification failed');
      }

      localStorage.setItem('adminAuth', 'true');
      localStorage.setItem('adminEmail', loginEmail);
      setIsAuthenticated(true);
      setEmail(loginEmail);
    } finally {
      setIsLoading(false);
    }
  };

  const logout = () => {
    localStorage.removeItem('adminAuth');
    localStorage.removeItem('adminEmail');
    setIsAuthenticated(false);
    setEmail(null);
  };

  return (
    <AuthContext.Provider value={{ isAuthenticated, isLoading, email, login, logout }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within AuthProvider');
  }
  return context;
}
