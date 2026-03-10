import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useAuth } from '@/hooks/useAuth'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'

type Mode = 'signin' | 'signup'

export default function Login() {
  const { signIn, signUp } = useAuth()
  const navigate = useNavigate()
  const [mode, setMode] = useState<Mode>('signin')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const [signupSuccess, setSignupSuccess] = useState(false)

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    setError('')
    setLoading(true)

    if (mode === 'signin') {
      const err = await signIn(email, password)
      if (err) {
        setError(err.message)
      } else {
        navigate('/')
      }
    } else {
      const err = await signUp(email, password)
      if (err) {
        setError(err.message)
      } else {
        setSignupSuccess(true)
      }
    }

    setLoading(false)
  }

  return (
    <div className="min-h-screen bg-canvas flex items-center justify-center px-4">
      <div className="w-full max-w-sm">
        {/* Header */}
        <div className="mb-8">
          <h1 className="text-[32px] font-bold text-olive">Covey Ledger</h1>
          <p className="text-gray-500 text-sm mt-1">Field-grade hunting compliance tracker.</p>
        </div>

        {signupSuccess ? (
          <div className="bg-[#e6f0e8] border border-forest/30 rounded p-4 text-sm text-forest">
            Account created. Check your email to confirm, then sign in.
          </div>
        ) : (
          <form onSubmit={handleSubmit} className="space-y-4">
            <Input
              id="email"
              type="email"
              label="Email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="hunter@example.com"
              required
              autoComplete="email"
            />
            <Input
              id="password"
              type="password"
              label="Password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="••••••••"
              required
              autoComplete={mode === 'signin' ? 'current-password' : 'new-password'}
            />

            {error && (
              <p className="text-sm text-rust bg-[#fce8e6] border border-rust/30 rounded px-3 py-2">
                {error}
              </p>
            )}

            <Button type="submit" size="lg" className="w-full" disabled={loading}>
              {loading ? 'Please wait...' : mode === 'signin' ? 'Sign in' : 'Create account'}
            </Button>

            <p className="text-center text-sm text-gray-500">
              {mode === 'signin' ? "Don't have an account? " : 'Already have an account? '}
              <button
                type="button"
                onClick={() => { setMode(mode === 'signin' ? 'signup' : 'signin'); setError('') }}
                className="text-burnt hover:underline font-medium"
              >
                {mode === 'signin' ? 'Sign up' : 'Sign in'}
              </button>
            </p>
          </form>
        )}
      </div>
    </div>
  )
}
