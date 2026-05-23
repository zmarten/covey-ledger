import { lazy, Suspense } from 'react'
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import Landing from '@/pages/Landing'

const Login = lazy(() => import('@/pages/Login'))
const AuthenticatedApp = lazy(() => import('@/pages/AuthenticatedApp'))

function RouteLoader() {
  return <div className="min-h-screen bg-canvas flex items-center justify-center text-olive text-sm">Loading...</div>
}

export default function App() {
  return (
    <BrowserRouter>
      <Suspense fallback={<RouteLoader />}>
        <Routes>
          <Route path="/" element={<Landing />} />
          <Route path="/login" element={<Login />} />
          <Route path="/app/*" element={<AuthenticatedApp />} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </Suspense>
    </BrowserRouter>
  )
}
