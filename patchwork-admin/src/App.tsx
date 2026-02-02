import { ConvexProvider, ConvexReactClient } from 'convex/react'
import { AuthProvider, useAuth } from './context/AuthContext'
import { Login } from './pages/Login'
import { UserList } from './pages/UserList'
import { UserDetail } from './pages/UserDetail'
import { useState } from 'react'
import type { Id } from '../../Patchwork_MCP/convex/_generated/dataModel'

const convexUrl = import.meta.env.VITE_CONVEX_URL
if (!convexUrl) {
  throw new Error('VITE_CONVEX_URL is not set')
}

const convex = new ConvexReactClient(convexUrl)

function AppContent() {
  const { isAuthenticated, isLoading } = useAuth()
  const [selectedUserId, setSelectedUserId] = useState<string | null>(null)

  if (isLoading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-slate-900 to-slate-800 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-white mx-auto mb-4"></div>
          <p className="text-white">Loading...</p>
        </div>
      </div>
    )
  }

  if (!isAuthenticated) {
    return <Login />
  }

  if (selectedUserId) {
    return (
      <div className="min-h-screen bg-slate-900 min-h-screen">
        <UserDetail 
          userId={selectedUserId as Id<"users">} 
          onBack={() => setSelectedUserId(null)} 
        />
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-slate-900">
      <UserList onSelectUser={setSelectedUserId} />
    </div>
  )
}

function App() {
  return (
    <ConvexProvider client={convex}>
      <AuthProvider>
        <AppContent />
      </AuthProvider>
    </ConvexProvider>
  )
}

export default App
