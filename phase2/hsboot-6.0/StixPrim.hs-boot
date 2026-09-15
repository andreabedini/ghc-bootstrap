module StixPrim where
import AbsCSyn
import {-# SOURCE #-} Stix

amodeToStix :: AbsCSyn.CAddrMode -> Stix.StixExpr
