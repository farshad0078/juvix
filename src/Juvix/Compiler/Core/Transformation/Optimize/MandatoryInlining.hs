module Juvix.Compiler.Core.Transformation.Optimize.MandatoryInlining where

import Juvix.Compiler.Core.Extra
import Juvix.Compiler.Core.Transformation.Base

convertNode :: InfoTable -> Node -> Node
convertNode tab = dmap go
  where
    go :: Node -> Node
    go node = case node of
      NIdt Ident {..}
        | Just InlineAlways <- lookupIdentifierInfo tab _identSymbol ^. identifierPragmas . pragmasInline ->
            lookupIdentifierNode tab _identSymbol
      NCase cs@Case {..} -> case _caseValue of
        NIdt Ident {..}
          | Just InlineCase <- lookupIdentifierInfo tab _identSymbol ^. identifierPragmas . pragmasInline ->
              NCase cs {_caseValue = lookupIdentifierNode tab _identSymbol}
        _ ->
          node
      _ ->
        node

mandatoryInlining :: InfoTable -> InfoTable
mandatoryInlining tab = mapAllNodes (convertNode tab) tab
