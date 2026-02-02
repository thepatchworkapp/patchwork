import { useState } from 'react';
import { sendOTP, getAdminEmail } from '../lib/auth';
import { useAuth } from '../context/AuthContext';
import { Shield, Mail, KeyRound, ArrowRight, ArrowLeft, Loader2, AlertCircle, CheckCircle2 } from 'lucide-react';

export function Login() {
  const { login } = useAuth();
  const [email, setEmail] = useState(getAdminEmail());
  const [otp, setOtp] = useState('');
  const [error, setError] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [otpSent, setOtpSent] = useState(false);

  const handleSendOTP = async () => {
    setError('');
    setIsLoading(true);
    try {
      await sendOTP(email);
      setOtpSent(true);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to send OTP');
    } finally {
      setIsLoading(false);
    }
  };

  const handleVerify = async () => {
    setError('');
    
    if (otp.length !== 6) {
      setError('Please enter a 6-digit OTP');
      return;
    }

    setIsLoading(true);
    try {
      await login(email, otp);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Verification failed');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-900 via-indigo-950 to-slate-900 flex items-center justify-center p-4">
      {/* Background pattern */}
      <div className="absolute inset-0 bg-[url('data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNjAiIGhlaWdodD0iNjAiIHZpZXdCb3g9IjAgMCA2MCA2MCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48ZyBmaWxsPSJub25lIiBmaWxsLXJ1bGU9ImV2ZW5vZGQiPjxnIGZpbGw9IiNmZmYiIGZpbGwtb3BhY2l0eT0iMC4wMyI+PHBhdGggZD0iTTM2IDM0djItSDI0di0yaDEyek0zNiAyNHYySDI0di0yaDEyeiIvPjwvZz48L2c+PC9zdmc+')] opacity-50"></div>
      
      <div className="relative w-full max-w-md">
        {/* Logo/Brand */}
        <div className="text-center mb-8">
          <div className="inline-flex items-center justify-center w-16 h-16 bg-gradient-to-br from-indigo-500 to-purple-600 rounded-2xl shadow-lg shadow-indigo-500/30 mb-4">
            <Shield className="w-8 h-8 text-white" />
          </div>
          <h1 className="text-3xl font-bold text-white mb-2">Admin Login</h1>
          <p className="text-slate-400">Patchwork Admin Dashboard</p>
        </div>

        {/* Login Card */}
        <div className="bg-white/10 backdrop-blur-xl rounded-2xl shadow-2xl border border-white/10 p-8">
          {/* Progress indicator */}
          <div className="flex items-center justify-center mb-8">
            <div className={`flex items-center justify-center w-10 h-10 rounded-full ${!otpSent ? 'bg-indigo-500 text-white' : 'bg-green-500 text-white'} transition-colors`}>
              {otpSent ? <CheckCircle2 className="w-5 h-5" /> : <Mail className="w-5 h-5" />}
            </div>
            <div className={`w-16 h-1 mx-2 rounded-full ${otpSent ? 'bg-green-500' : 'bg-slate-600'} transition-colors`}></div>
            <div className={`flex items-center justify-center w-10 h-10 rounded-full ${otpSent ? 'bg-indigo-500 text-white' : 'bg-slate-600 text-slate-400'} transition-colors`}>
              <KeyRound className="w-5 h-5" />
            </div>
          </div>

          <div className="space-y-6">
            {/* Email Input */}
            <div>
              <label className="block text-sm font-medium text-slate-300 mb-2">
                Admin Email
              </label>
              <div className="relative">
                <Mail className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-slate-400" />
                <input
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  disabled={otpSent}
                  className="w-full pl-11 pr-4 py-3 bg-slate-800/50 border border-slate-600 rounded-xl text-white placeholder-slate-500 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent disabled:bg-slate-800/30 disabled:text-slate-400 disabled:cursor-not-allowed transition-all"
                  placeholder="daveald@gmail.com"
                />
              </div>
              <p className="text-xs text-slate-500 mt-2 flex items-center gap-1">
                <Shield className="w-3 h-3" />
                Only authorized administrators can access
              </p>
            </div>

            {/* OTP Input */}
            {otpSent && (
              <div>
                <label className="block text-sm font-medium text-slate-300 mb-2">
                  Verification Code
                </label>
                <div className="relative">
                  <KeyRound className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-slate-400" />
                  <input
                    type="text"
                    value={otp}
                    onChange={(e) => setOtp(e.target.value.replace(/\D/g, '').slice(0, 6))}
                    maxLength={6}
                    autoFocus
                    className="w-full pl-11 pr-4 py-3 bg-slate-800/50 border border-slate-600 rounded-xl text-white text-center text-2xl tracking-[0.5em] font-mono placeholder-slate-600 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-transparent transition-all"
                    placeholder="------"
                  />
                </div>
                <p className="text-xs text-amber-400/80 mt-2 flex items-center gap-1">
                  <AlertCircle className="w-3 h-3" />
                  Check browser console (F12) for OTP code
                </p>
              </div>
            )}

            {/* Error Message */}
            {error && (
              <div className="p-4 bg-red-500/10 border border-red-500/30 rounded-xl">
                <p className="text-sm text-red-400 flex items-center gap-2">
                  <AlertCircle className="w-4 h-4 flex-shrink-0" />
                  {error}
                </p>
              </div>
            )}

            {/* Action Buttons */}
            <div className="space-y-3 pt-2">
              {!otpSent ? (
                <button
                  onClick={handleSendOTP}
                  disabled={isLoading || !email}
                  className="w-full bg-gradient-to-r from-indigo-500 to-purple-600 hover:from-indigo-600 hover:to-purple-700 disabled:from-slate-600 disabled:to-slate-600 disabled:cursor-not-allowed text-white font-semibold py-3 px-4 rounded-xl transition-all duration-200 flex items-center justify-center gap-2 shadow-lg shadow-indigo-500/25 hover:shadow-indigo-500/40"
                >
                  {isLoading ? (
                    <>
                      <Loader2 className="w-5 h-5 animate-spin" />
                      Sending...
                    </>
                  ) : (
                    <>
                      Send Verification Code
                      <ArrowRight className="w-5 h-5" />
                    </>
                  )}
                </button>
              ) : (
                <>
                  <button
                    onClick={handleVerify}
                    disabled={isLoading || otp.length !== 6}
                    className="w-full bg-gradient-to-r from-indigo-500 to-purple-600 hover:from-indigo-600 hover:to-purple-700 disabled:from-slate-600 disabled:to-slate-600 disabled:cursor-not-allowed text-white font-semibold py-3 px-4 rounded-xl transition-all duration-200 flex items-center justify-center gap-2 shadow-lg shadow-indigo-500/25 hover:shadow-indigo-500/40"
                  >
                    {isLoading ? (
                      <>
                        <Loader2 className="w-5 h-5 animate-spin" />
                        Verifying...
                      </>
                    ) : (
                      <>
                        <Shield className="w-5 h-5" />
                        Verify & Login
                      </>
                    )}
                  </button>
                  <button
                    onClick={() => {
                      setOtpSent(false);
                      setOtp('');
                      setError('');
                    }}
                    disabled={isLoading}
                    className="w-full bg-slate-700/50 hover:bg-slate-700 text-slate-300 font-medium py-3 px-4 rounded-xl transition-all duration-200 flex items-center justify-center gap-2"
                  >
                    <ArrowLeft className="w-4 h-4" />
                    Use Different Email
                  </button>
                </>
              )}
            </div>
          </div>
        </div>

        {/* Footer */}
        <p className="text-center text-slate-500 text-xs mt-6">
          Protected by secure OTP authentication
        </p>
      </div>
    </div>
  );
}
