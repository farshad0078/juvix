-- An optimizing transformation that folds lets whose values are immediate,
-- i.e., they don't require evaluation or memory allocation (variables or
-- constants).
--
-- For example, transforms
-- ```
-- let x := y in let z := x + x in x + z
-- ```
-- to
-- ```
-- let z := y + y in y + z
-- ```
module Juvix.Compiler.Core.Transformation.Optimize.LetFolding where

import Juvix.Compiler.Core.Extra
import Juvix.Compiler.Core.Transformation.Base

convertNode :: Node -> Node
convertNode = rmap go
  where
    go :: ([BinderChange] -> Node -> Node) -> Node -> Node
    go recur = \case
      NLet Let {..}
        | isImmediate (_letItem ^. letItemValue) ->
            go (recur . (mkBCRemove (_letItem ^. letItemBinder) val' :)) _letBody
        where
          val' = go recur (_letItem ^. letItemValue)
      node ->
        recur [] node

letFolding :: InfoTable -> InfoTable
letFolding = mapAllNodes convertNode