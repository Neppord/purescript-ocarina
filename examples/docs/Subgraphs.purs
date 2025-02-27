module Ocarina.Example.Docs.Subgraphs where

import Prelude

import Bolson.Core (envy)
import Deku.Core (Nut)
import Deku.Pursx ((~~))
import Effect (Effect)
import FRP.Event (Event)
import Ocarina.Control (gain_, loopBuf)
import Ocarina.Core (bangOn)
import Ocarina.Example.Docs.Subgraph.SliderEx as SliderEx
import Ocarina.Example.Docs.Types (CancelCurrentAudio, Page, SingleSubgraphEvent, SingleSubgraphPusher)
import Ocarina.Example.Docs.Util (audioWrapperSpan, ccassp)
import Ocarina.Interpret (decodeAudioDataFromUri)
import Ocarina.Run (run2)
import Type.Proxy (Proxy(..))

px =  Proxy :: Proxy """<div>
  <h1>Subgraphs</h1>

  <h2>Making audio even more dynamic</h2>
  <p>
    When we're creating video games or other types of interactive work, it's rare that we'll be able to anticipate the exact web audio graph we'll need for an entire session. As an example, imagine that in a video game a certain sound effects accompany various characters, and those characters come in and out based on your progress through the game. One way to solve this would be to anticipate the maximum number of characters that are present in a game and do a round-robin assignment of nodes in the audio graph as characters enter and leave your game. But sometimes that's not ergonomic, and in certain cases its downright inefficient. Another downside is that it does not allow for specialization of the web audio graph based on new data, like for example a character to play a custom sound once you've earned a certain badge.
  </p>

  <p>
    Subgraphs fix this problem. They provide a concise mechansim to dynamically insert audio graphs based on events.
  </p>

  ~suby~

  <h2>Go forth and be brilliant!</h2>
  <p>Thus ends the first version of the ocarina documentation. Applause is always welcome ~appl~! Alas, some features remain undocumented, like audio worklets and an imperative API. At some point I hope to document all of these, but hopefully this should be enough to get anyone interested up and running. If you need to use any of those features before I document them, ping me on the <a href="https://purescript.org/chat">PureScript Discord</a>. Otherwise, happy music making with Ocarina!</p>
</div>"""

subgraphs :: CancelCurrentAudio -> (Page -> Effect Unit) -> SingleSubgraphPusher -> Event SingleSubgraphEvent  -> Nut
subgraphs cca' dpage ssp ev = px ~~
  { appl:
      ( audioWrapperSpan "👏" ev ccb (\ctx -> decodeAudioDataFromUri ctx "https://freesound.org/data/previews/277/277021_1402315-lq.mp3")
          \ctx buf -> run2 ctx [ gain_ 1.0 [ loopBuf buf bangOn ] ]
      ),
    suby: SliderEx.sgSliderEx ccb dpage ev
    -- next: pure (D.OnClick := (cb (const $ dpage Intro *> scrollToTop)))
  }
  where
  ccb = ccassp cca' ssp