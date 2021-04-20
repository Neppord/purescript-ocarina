module WAGS.Example.KitchenSink.Types.SquareOsc where

import Prelude

import Data.Identity (Identity(..))
import Math (cos, pi, pow, sin, (%))
import WAGS.Control.Types (Universe')
import WAGS.Example.KitchenSink.Timing (ksSquareOscIntegral, ksSquareOscTime, pieceTime)
import WAGS.Example.KitchenSink.Types.Empty (BaseGraph, EI0, EI1)
import WAGS.Graph.Constructors (Gain, Speaker, SquareOsc)
import WAGS.Graph.Decorators (Focus(..), Decorating')
import WAGS.Graph.Optionals (GetSetAP, gain, speaker, squareOsc)
import WAGS.Universe.AudioUnit (TSquareOsc)
import WAGS.Universe.EdgeProfile (NoEdge)
import WAGS.Universe.Graph (GraphC)
import WAGS.Universe.Node (NodeC)

ksSquareOscBegins = ksSquareOscIntegral - ksSquareOscTime :: Number

type SquareOscGraph
  = GraphC
      (NodeC (TSquareOsc EI0) NoEdge)
      (BaseGraph EI0)

type SquareOscUniverse cb
  = Universe' EI1 SquareOscGraph cb

type KsSquareOsc g t
  = Speaker (g (Gain GetSetAP (t (SquareOsc GetSetAP))))

ksSquareOsc' ::
  forall g t.
  Decorating' g ->
  Decorating' t ->
  KsSquareOsc g t
ksSquareOsc' fg ft = speaker (fg $ gain 0.0 (ft $ squareOsc 440.0))

ksSquareOsc :: KsSquareOsc Identity Identity
ksSquareOsc = ksSquareOsc' Identity Identity

ksSquareOscSquareOsc :: KsSquareOsc Identity Focus
ksSquareOscSquareOsc = ksSquareOsc' Identity Focus

ksSquareOscGain :: KsSquareOsc Focus Identity
ksSquareOscGain = ksSquareOsc' Focus Identity

deltaKsSquareOsc :: Number -> Speaker (Gain GetSetAP (SquareOsc GetSetAP))
deltaKsSquareOsc =
  (_ % pieceTime)
    >>> (_ - ksSquareOscBegins)
    >>> (max 0.0)
    >>> \time ->
        let
          rad = pi * time
        in
          speaker
            $ gain (0.1 - 0.3 * (cos time))
                (squareOsc (440.0 + 50.0 * ((sin (rad * 1.5)) `pow` 2.0)))
