-- | Stuff that is generated when the pipeline is run
--
-- Arguments to the *Artifacts functions in this module should not modify the
-- Artifacts State since any changes will be overwritten by the
-- `runStateLikeArtifacts` wrapper.
module Juvix.Compiler.Pipeline.Artifacts
  ( module Juvix.Compiler.Pipeline.Artifacts,
    module Juvix.Compiler.Pipeline.Artifacts.Base,
  )
where

import Juvix.Compiler.Builtins
import Juvix.Compiler.Concrete.Data.InfoTableBuilder qualified as Scoped
import Juvix.Compiler.Concrete.Data.ParsedInfoTableBuilder qualified as Concrete
import Juvix.Compiler.Concrete.Data.Scope
import Juvix.Compiler.Concrete.Data.Scope qualified as S
import Juvix.Compiler.Concrete.Translation.FromParsed.Analysis.Scoping (ScoperError)
import Juvix.Compiler.Core.Data.InfoTableBuilder qualified as Core
import Juvix.Compiler.Internal.Extra.DependencyBuilder (ExportsTable)
import Juvix.Compiler.Internal.Language qualified as Internal
import Juvix.Compiler.Internal.Translation.FromConcrete qualified as Internal
import Juvix.Compiler.Internal.Translation.FromInternal.Analysis.Termination.Checker
import Juvix.Compiler.Internal.Translation.FromInternal.Analysis.TypeChecking.Data.Context
import Juvix.Compiler.Pipeline.Artifacts.Base
import Juvix.Compiler.Pipeline.EntryPoint
import Juvix.Prelude

-- | It only reads the Artifacts. It does not modify the table in it.
extendedTableReplArtifacts :: forall r. (Members '[State Artifacts] r) => Internal.Expression -> Sem r Internal.InfoTable
extendedTableReplArtifacts e = Internal.extendWithReplExpression e <$> gets (^. artifactInternalTypedTable)

runCoreInfoTableBuilderArtifacts :: (Members '[State Artifacts] r) => Sem (Core.InfoTableBuilder ': r) a -> Sem r a
runCoreInfoTableBuilderArtifacts = runStateLikeArtifacts Core.runInfoTableBuilder artifactCoreTable

tmpCoreInfoTableBuilderArtifacts :: (Members '[State Artifacts] r) => Sem (Core.InfoTableBuilder ': r) a -> Sem r a
tmpCoreInfoTableBuilderArtifacts m = do
  tbl <- gets (^. artifactCoreTable)
  a <- runStateLikeArtifacts Core.runInfoTableBuilder artifactCoreTable m
  modify' (set artifactCoreTable tbl)
  return a

runBuiltinsArtifacts :: (Members '[Error JuvixError, State Artifacts] r) => Sem (Builtins ': r) a -> Sem r a
runBuiltinsArtifacts = runStateLikeArtifacts runBuiltins artifactBuiltins

runParserInfoTableBuilderArtifacts :: (Members '[State Artifacts] r) => Sem (Concrete.InfoTableBuilder ': r) a -> Sem r a
runParserInfoTableBuilderArtifacts = runStateLikeArtifacts Concrete.runParserInfoTableBuilderRepl artifactParsing

runScoperInfoTableBuilderArtifacts :: (Members '[State Artifacts] r) => Sem (Scoped.InfoTableBuilder ': r) a -> Sem r a
runScoperInfoTableBuilderArtifacts = runStateLikeArtifacts Scoped.runInfoTableBuilderRepl artifactScopeTable

runScoperScopeArtifacts :: (Members '[State Artifacts] r) => Sem (State S.Scope ': r) a -> Sem r a
runScoperScopeArtifacts m = do
  s <- fromJust <$> gets (^. artifactMainModuleScope)
  (s', a) <- runState s m
  modify' (set artifactMainModuleScope (Just s'))
  return a

runNameIdGenArtifacts ::
  (Members '[State Artifacts] r) =>
  Sem (NameIdGen ': r) a ->
  Sem r a
runNameIdGenArtifacts = runStateLikeArtifacts runNameIdGen artifactNameIdState

runFunctionsTableArtifacts :: (Members '[State Artifacts] r) => Sem (State FunctionsTable ': r) a -> Sem r a
runFunctionsTableArtifacts = runStateArtifacts artifactFunctions

readerTypesTableArtifacts :: (Members '[State Artifacts] r) => Sem (Reader TypesTable ': r) a -> Sem r a
readerTypesTableArtifacts = runReaderArtifacts artifactTypes

runTerminationArtifacts :: (Members '[Error JuvixError, State Artifacts] r) => Sem (Termination ': r) a -> Sem r a
runTerminationArtifacts = runStateLikeArtifacts runTermination artifactTerminationState

runTypesTableArtifacts :: (Members '[State Artifacts] r) => Sem (State TypesTable ': r) a -> Sem r a
runTypesTableArtifacts = runStateArtifacts artifactTypes

runStateArtifacts :: (Members '[State Artifacts] r) => Lens' Artifacts f -> Sem (State f ': r) a -> Sem r a
runStateArtifacts = runStateLikeArtifacts runState

runReaderArtifacts :: (Members '[State Artifacts] r) => Lens' Artifacts f -> Sem (Reader f ': r) a -> Sem r a
runReaderArtifacts l m = do
  s <- gets (^. l)
  runReader s m

runStateLikeArtifacts ::
  (Members '[State Artifacts] r) =>
  (field -> Sem (stateEff ': r) a -> Sem r (field, a)) ->
  Lens' Artifacts field ->
  Sem (stateEff ': r) a ->
  Sem r a
runStateLikeArtifacts runEff l m = do
  s <- gets (^. l)
  (s', a) <- runEff s m
  modify' (set l s')
  return a

runCacheArtifacts ::
  (Hashable k, Members '[State Artifacts] r) =>
  Lens' Artifacts (HashMap k v) ->
  (k -> Sem (Cache k v ': r) v) ->
  (Sem (Cache k v ': r) a) ->
  Sem r a
runCacheArtifacts l f = runStateLikeArtifacts (runCache f) l

runFromConcreteCache ::
  (Members '[Reader EntryPoint, State Artifacts, Builtins, NameIdGen, Reader ExportsTable, Error JuvixError] r) =>
  Sem (Internal.MCache ': r) a ->
  Sem r a
runFromConcreteCache =
  runCacheArtifacts
    (artifactInternalModuleCache . Internal.cachedModules)
    $ mapError (JuvixError @ScoperError)
      . runReader (mempty :: Pragmas)
      . runReader (mempty :: Internal.DefaultArgsStack)
      . evalState (mempty :: Internal.ConstructorInfos)
      . runTerminationArtifacts
      . runReaderArtifacts (artifactScoperState . scoperScopedSignatures)
      . runReaderArtifacts (artifactScoperState . scoperScopedConstructorFields)
      . Internal.goModuleNoCache
