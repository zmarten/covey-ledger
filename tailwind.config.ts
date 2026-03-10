import type { Config } from 'tailwindcss'

const config: Config = {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        olive: {
          DEFAULT: '#3A4A2A',
          dark: '#2C3820',
          light: '#4A5A38',
        },
        burnt: {
          DEFAULT: '#C05621',
          dark: '#9A4419',
          light: '#D4682F',
        },
        canvas: '#F4F1EA',
        khaki: '#E8E3D8',
        forest: '#2F5D3A',
        warn: '#B7791F',
        rust: {
          DEFAULT: '#8B2E1E',
          light: '#A3382A',
        },
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', '-apple-system', 'sans-serif'],
      },
      borderRadius: {
        sm: '2px',
        DEFAULT: '4px',
        md: '4px',
        lg: '4px',
      },
    },
  },
  plugins: [],
}

export default config
