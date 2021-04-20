module WAGS.Example.KitchenSink.Types.Peaking where

import Prelude

import Data.Identity (Identity(..))
import Math ((%))
import Type.Proxy (Proxy(..))
import WAGS.Control.Types (Universe')
import WAGS.Example.KitchenSink.Timing (calcSlope, ksPeakingIntegral, ksPeakingTime, pieceTime)
import WAGS.Example.KitchenSink.Types.Empty (BaseGraph, EI0, EI1, EI2)
import WAGS.Graph.Constructors (Peaking, Gain, PlayBuf, Speaker)
import WAGS.Graph.Decorators (Focus(..), Decorating')
import WAGS.Graph.Optionals (GetSetAP, gain, peaking, playBuf, speaker)
import WAGS.Universe.AudioUnit (TPeaking, TPlayBuf)
import WAGS.Universe.EdgeProfile (NoEdge, SingleEdge)
import WAGS.Universe.Graph (GraphC)
import WAGS.Universe.Node (NodeC, NodeListCons)

ksPeakingBegins = ksPeakingIntegral - ksPeakingTime :: Number

type PeakingGraph
  = GraphC
      (NodeC (TPeaking EI0) (SingleEdge EI1))
      ( NodeListCons
          (NodeC (TPlayBuf EI1 "my-buffer") NoEdge)
          (BaseGraph EI0)
      )

type PeakingUniverse cb
  = Universe' EI2 PeakingGraph cb

type KsPeakingreate (t :: Type -> Type) b
  = t (Peaking GetSetAP GetSetAP GetSetAP (b (PlayBuf "my-buffer" GetSetAP)))

type KsPeaking g t b
  = Speaker (g (Gain GetSetAP (KsPeakingreate t b)))

ksPeakingCreate ::
  forall t b.
  Decorating' t ->
  Decorating' b ->
  KsPeakingreate t b
ksPeakingCreate ft fb = ft $ peaking { freq: 300.0 } (fb $ playBuf (Proxy :: _ "my-buffer"))

ksPeaking' ::
  forall g t b.
  Decorating' g ->
  Decorating' t ->
  Decorating' b ->
  KsPeaking g t b
ksPeaking' fg ft fb =
  speaker
    (fg $ gain 1.0 (ksPeakingCreate ft fb))

ksPeaking :: KsPeaking Identity Identity Identity
ksPeaking = ksPeaking' Identity Identity Identity

ksPeakingPlaybuf :: KsPeaking Identity Identity Focus
ksPeakingPlaybuf = ksPeaking' Identity Identity Focus

ksPeakingPeaking :: KsPeaking Identity Focus Identity
ksPeakingPeaking = ksPeaking' Identity Focus Identity

ksPeakingGain :: KsPeaking Focus Identity Identity
ksPeakingGain = ksPeaking' Focus Identity Identity

deltaKsPeaking :: Number -> KsPeaking Identity Identity Identity
deltaKsPeaking =
  (_ % pieceTime)
    >>> (_ - ksPeakingBegins)
    >>> (max 0.0)
    >>> \time ->
        speaker
          ( Identity
              $ gain (if time > 9.0 then 0.0 else 1.0)
                  (Identity $ peaking { freq: (calcSlope 0.0 300.0 ksPeakingTime 200.0 time) } (Identity $ playBuf (Proxy :: _ "my-buffer")))
          )
