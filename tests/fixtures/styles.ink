import { Theme } from "@kraken/ink"

const pageWidth = 70rem
const surface = linear-gradient( _
  147deg, _
  hsl(200 100% 50%), _
  hsl(60 80% 80%) _
)

const light = new Theme({
  site: {
    background: =surface
    foreground: black
  }
})

export default {
  *, *::before, *::after: {
    boxSizing: border-box
    margin: 0
  }

  body: {
    display: grid
    maxWidth: min(=pageWidth, 100%)
    backgroundImage: url(/assets/hero.svg?theme=dark&scale=2)
  }

  @media (width >= 48rem): {
    body: {
      gridTemplateColumns: 1fr 1fr
    }
  }

  light: =light
} as const
