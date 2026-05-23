import { useState } from 'react'
import { Link } from 'react-router-dom'
import { ArrowRight, Binoculars, CheckCircle2, MapPinned, ShieldCheck, Snowflake, Watch } from 'lucide-react'

const workflow = [
  {
    icon: Watch,
    title: 'Field log',
    copy: 'Capture flushes, shots, downed birds, dog status, and session notes from a Garmin watch while your phone stays packed away.',
  },
  {
    icon: Snowflake,
    title: 'Freezer ledger',
    copy: 'Bring the hunt home into a freezer inventory that remembers state, species, hunter split, gifted birds, and consumed birds.',
  },
  {
    icon: ShieldCheck,
    title: 'Compliance check',
    copy: 'See daily and possession-limit pressure before you head back out, with an exportable record for responsible hunting.',
  },
]

const bullets = [
  'Garmin-native capture for upland hunts',
  'Possession and daily-limit dashboard',
  'Bird split tool for hunting parties',
  'Freezer inventory by state and species',
]

type SubmitState = 'idle' | 'submitting' | 'success' | 'error'

export default function Landing() {
  const [email, setEmail] = useState('')
  const [statesHunted, setStatesHunted] = useState('')
  const [toolsUsed, setToolsUsed] = useState('')
  const [biggestPain, setBiggestPain] = useState('')
  const [submitState, setSubmitState] = useState<SubmitState>('idle')
  const [message, setMessage] = useState('')

  async function handleWaitlistSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setSubmitState('submitting')
    setMessage('')

    try {
      const { joinWaitlist } = await import('@/lib/waitlist')
      await joinWaitlist({ email, statesHunted, toolsUsed, biggestPain, source: 'covey-landing' })
      setSubmitState('success')
      setMessage('You are on the early-access list. I will reach out when the next Covey test build is ready.')
      setEmail('')
      setStatesHunted('')
      setToolsUsed('')
      setBiggestPain('')
    } catch (error) {
      setSubmitState('error')
      setMessage(error instanceof Error ? error.message : 'Could not join the waitlist. Please try again or email zachdmartens@gmail.com.')
    }
  }

  return (
    <main className="min-h-screen bg-canvas text-olive">
      <section className="mx-auto flex max-w-6xl flex-col gap-12 px-4 py-6 sm:px-6 lg:px-8 lg:py-10">
        <nav className="flex items-center justify-between gap-4">
          <Link to="/" className="flex items-center gap-2 font-bold tracking-tight text-olive">
            <span className="flex h-9 w-9 items-center justify-center rounded bg-olive text-canvas">
              <Binoculars size={18} />
            </span>
            Covey Ledger
          </Link>
          <div className="flex items-center gap-3 text-sm font-medium">
            <a href="https://my-project-omega-ivory-38.vercel.app" className="hidden text-olive/70 transition hover:text-olive sm:inline">
              WaypointBridge
            </a>
            <Link to="/login" className="rounded border border-olive/20 px-3 py-2 text-olive transition hover:border-olive/50">
              Sign in
            </Link>
          </div>
        </nav>

        <div className="grid items-center gap-10 lg:grid-cols-[1.04fr_0.96fr]">
          <div className="space-y-7">
            <div className="inline-flex items-center gap-2 rounded-full border border-burnt/30 bg-burnt/10 px-3 py-1 text-sm font-semibold text-burnt-dark">
              Garmin field log → freezer ledger → compliance check
            </div>
            <div className="space-y-5">
              <h1 className="max-w-3xl text-4xl font-bold leading-tight text-olive sm:text-5xl lg:text-6xl">
                The hunting logbook that follows birds from the field to the freezer.
              </h1>
              <p className="max-w-2xl text-lg leading-8 text-olive/75">
                Covey Ledger helps upland hunters record what happened in the field, split birds cleanly across a party, and understand possession-limit pressure before the next hunt.
              </p>
            </div>
            <div className="flex flex-col gap-3 sm:flex-row">
              <a
                href="#waitlist"
                className="inline-flex items-center justify-center gap-2 rounded bg-burnt px-5 py-3 text-sm font-bold text-white shadow-sm transition hover:bg-burnt-dark"
              >
                Join the waitlist <ArrowRight size={16} />
              </a>
              <a
                href="https://my-project-omega-ivory-38.vercel.app"
                className="inline-flex items-center justify-center gap-2 rounded border border-olive/25 px-5 py-3 text-sm font-bold text-olive transition hover:border-olive/60 hover:bg-khaki"
              >
                Try WaypointBridge free
              </a>
            </div>
            <div className="grid gap-2 text-sm text-olive/75 sm:grid-cols-2">
              {bullets.map((bullet) => (
                <div key={bullet} className="flex items-center gap-2">
                  <CheckCircle2 className="shrink-0 text-forest" size={16} />
                  <span>{bullet}</span>
                </div>
              ))}
            </div>
          </div>

          <div className="relative">
            <div className="absolute -left-5 top-8 hidden h-32 w-32 rounded-full bg-burnt/15 blur-2xl lg:block" />
            <div className="absolute -right-8 bottom-6 hidden h-40 w-40 rounded-full bg-forest/15 blur-2xl lg:block" />
            <div className="relative rounded-[18px] border border-olive/15 bg-[#ede7db] p-4 shadow-2xl shadow-olive/10">
              <div className="rounded-[14px] bg-olive p-4 text-canvas shadow-inner">
                <div className="mb-4 flex items-center justify-between text-xs text-canvas/60">
                  <span>UplandHunter</span>
                  <span>Garmin mockup</span>
                </div>
                <div className="grid gap-4 md:grid-cols-[0.72fr_1fr]">
                  <div className="rounded-[28px] border-8 border-olive-dark bg-[#11170d] p-4 text-center shadow-xl">
                    <div className="mx-auto mb-4 h-2 w-16 rounded-full bg-canvas/20" />
                    <p className="text-xs uppercase tracking-[0.28em] text-canvas/50">Session</p>
                    <p className="mt-2 text-4xl font-bold tabular-nums">03</p>
                    <p className="text-xs text-canvas/60">flushes marked</p>
                    <div className="mt-5 grid grid-cols-2 gap-2 text-xs">
                      <div className="rounded bg-canvas/10 p-2">
                        <p className="text-canvas/45">Dog</p>
                        <p className="font-semibold">Point</p>
                      </div>
                      <div className="rounded bg-canvas/10 p-2">
                        <p className="text-canvas/45">Birds</p>
                        <p className="font-semibold">2 down</p>
                      </div>
                    </div>
                  </div>
                  <div className="space-y-3">
                    <div className="rounded bg-canvas p-4 text-olive">
                      <div className="mb-3 flex items-center justify-between">
                        <p className="font-semibold">Montana sharp-tailed grouse</p>
                        <span className="rounded-full bg-forest/10 px-2 py-1 text-xs font-bold text-forest">Clear</span>
                      </div>
                      <div className="space-y-3 text-sm">
                        <Meter label="Today" value="2 / 4" width="50%" />
                        <Meter label="Possession" value="6 / 12" width="50%" />
                      </div>
                    </div>
                    <div className="grid grid-cols-2 gap-3">
                      <MiniCard label="Freezer" value="18 birds" />
                      <MiniCard label="Party split" value="3 hunters" />
                    </div>
                    <div className="rounded bg-burnt/15 p-4 text-sm text-canvas">
                      <div className="mb-2 flex items-center gap-2 font-semibold">
                        <MapPinned size={16} /> WaypointBridge
                      </div>
                      Clean Garmin GPX waypoints, then export hunt context into the ledger.
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section className="border-y border-olive/10 bg-khaki/60">
        <div className="mx-auto grid max-w-6xl gap-4 px-4 py-10 sm:px-6 lg:grid-cols-3 lg:px-8">
          {workflow.map(({ icon: Icon, title, copy }) => (
            <article key={title} className="rounded-lg border border-olive/10 bg-canvas p-6 shadow-sm">
              <div className="mb-4 flex h-11 w-11 items-center justify-center rounded bg-olive text-canvas">
                <Icon size={20} />
              </div>
              <h2 className="text-xl font-bold text-olive">{title}</h2>
              <p className="mt-2 text-sm leading-6 text-olive/70">{copy}</p>
            </article>
          ))}
        </div>
      </section>

      <section id="waitlist" className="mx-auto max-w-6xl px-4 py-12 sm:px-6 lg:px-8">
        <div className="grid gap-6 rounded-xl bg-olive p-6 text-canvas sm:p-8 lg:grid-cols-[0.9fr_1.1fr] lg:gap-10">
          <div>
            <p className="text-sm font-semibold uppercase tracking-[0.22em] text-canvas/50">Early access</p>
            <h2 className="mt-2 text-2xl font-bold text-canvas sm:text-3xl">Help shape the Garmin-to-ledger workflow.</h2>
            <p className="mt-3 max-w-2xl text-sm leading-6 text-canvas/70">
              The first validation goal is simple: confirm hunters want a field capture + freezer/compliance workflow before building deeper automation.
            </p>
            <p className="mt-4 text-xs leading-5 text-canvas/50">
              Prefer email? Send notes to <a className="underline" href="mailto:zachdmartens@gmail.com">zachdmartens@gmail.com</a>.
            </p>
          </div>

          <form onSubmit={handleWaitlistSubmit} className="grid gap-3 rounded-lg bg-canvas p-4 text-olive shadow-lg sm:p-5">
            <label className="grid gap-1 text-sm font-semibold">
              Email
              <input
                required
                type="email"
                value={email}
                onChange={(event) => setEmail(event.target.value)}
                placeholder="hunter@example.com"
                className="rounded border border-olive/20 bg-white px-3 py-2 text-sm font-normal outline-none transition focus:border-burnt"
              />
            </label>
            <label className="grid gap-1 text-sm font-semibold">
              State(s) you hunt
              <input
                value={statesHunted}
                onChange={(event) => setStatesHunted(event.target.value)}
                placeholder="Montana, South Dakota, Kansas..."
                className="rounded border border-olive/20 bg-white px-3 py-2 text-sm font-normal outline-none transition focus:border-burnt"
              />
            </label>
            <label className="grid gap-1 text-sm font-semibold">
              Tools you already use
              <input
                value={toolsUsed}
                onChange={(event) => setToolsUsed(event.target.value)}
                placeholder="Garmin watch, Alpha/Astro, onX, paper log..."
                className="rounded border border-olive/20 bg-white px-3 py-2 text-sm font-normal outline-none transition focus:border-burnt"
              />
            </label>
            <label className="grid gap-1 text-sm font-semibold">
              Biggest pain today
              <textarea
                value={biggestPain}
                onChange={(event) => setBiggestPain(event.target.value)}
                placeholder="Field logging, waypoints, possession limits, freezer inventory, party splits..."
                rows={3}
                className="rounded border border-olive/20 bg-white px-3 py-2 text-sm font-normal outline-none transition focus:border-burnt"
              />
            </label>
            <button
              type="submit"
              disabled={submitState === 'submitting'}
              className="inline-flex items-center justify-center gap-2 rounded bg-burnt px-5 py-3 text-sm font-bold text-white transition hover:bg-burnt-dark disabled:cursor-not-allowed disabled:opacity-70"
            >
              {submitState === 'submitting' ? 'Joining...' : 'Request early access'} <ArrowRight size={16} />
            </button>
            {message && (
              <p className={submitState === 'error' ? 'text-sm text-rust' : 'text-sm text-forest'}>
                {message}
              </p>
            )}
          </form>
        </div>
      </section>
    </main>
  )
}

function Meter({ label, value, width }: { label: string; value: string; width: string }) {
  return (
    <div>
      <div className="mb-1 flex items-center justify-between text-xs text-olive/60">
        <span>{label}</span>
        <span>{value}</span>
      </div>
      <div className="h-2 rounded-full bg-khaki">
        <div className="h-2 rounded-full bg-forest" style={{ width }} />
      </div>
    </div>
  )
}

function MiniCard({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded bg-canvas/10 p-3">
      <p className="text-xs text-canvas/45">{label}</p>
      <p className="font-semibold text-canvas">{value}</p>
    </div>
  )
}
