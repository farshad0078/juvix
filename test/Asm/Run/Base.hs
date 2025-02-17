module Asm.Run.Base where

import Base
import Data.Text.IO qualified as TIO
import Juvix.Compiler.Asm.Data.InfoTable
import Juvix.Compiler.Asm.Error
import Juvix.Compiler.Asm.Interpreter
import Juvix.Compiler.Asm.Pretty
import Juvix.Compiler.Asm.Transformation.Validate
import Juvix.Compiler.Asm.Translation.FromSource
import Juvix.Data.PPOutput

asmRunAssertion' :: InfoTable -> Path Abs File -> (String -> IO ()) -> Assertion
asmRunAssertion' tab expectedFile step = do
  step "Validate"
  case validate' tab of
    Just err -> assertFailure (show (pretty err))
    Nothing ->
      case tab ^. infoMainFunction of
        Just sym -> do
          withTempDir'
            ( \dirPath -> do
                let outputFile = dirPath <//> $(mkRelFile "out.out")
                hout <- openFile (toFilePath outputFile) WriteMode
                step "Interpret"
                r' <- doRun hout tab (lookupFunInfo tab sym)
                case r' of
                  Left err -> do
                    hClose hout
                    assertFailure (show (pretty err))
                  Right value' -> do
                    case value' of
                      ValVoid -> return ()
                      _ -> hPutStrLn hout (ppPrint tab value')
                    hClose hout
                    actualOutput <- TIO.readFile (toFilePath outputFile)
                    step "Compare expected and actual program output"
                    expected <- TIO.readFile (toFilePath expectedFile)
                    assertEqDiffText ("Check: RUN output = " <> toFilePath expectedFile) actualOutput expected
            )
        Nothing -> assertFailure "no 'main' function"

asmRunAssertion :: Path Abs File -> Path Abs File -> (InfoTable -> Either AsmError InfoTable) -> (InfoTable -> Assertion) -> (String -> IO ()) -> Assertion
asmRunAssertion mainFile expectedFile trans testTrans step = do
  step "Parse"
  r <- parseFile mainFile
  case r of
    Left err -> assertFailure (show (pretty err))
    Right tab0 -> do
      case trans tab0 of
        Left err -> assertFailure (show (pretty err))
        Right tab -> do
          testTrans tab
          asmRunAssertion' tab expectedFile step

asmRunErrorAssertion :: Path Abs File -> (String -> IO ()) -> Assertion
asmRunErrorAssertion mainFile step = do
  step "Parse"
  r <- parseFile mainFile
  case r of
    Left _ -> assertBool "" True
    Right tab -> do
      step "Validate"
      case validate' tab of
        Just _ -> assertBool "" True
        Nothing ->
          case tab ^. infoMainFunction of
            Just sym -> do
              withTempDir'
                ( \dirPath -> do
                    let outputFile = dirPath <//> $(mkRelFile "out.out")
                    hout <- openFile (toFilePath outputFile) WriteMode
                    step "Interpret"
                    r' <- doRun hout tab (lookupFunInfo tab sym)
                    hClose hout
                    case r' of
                      Left _ -> assertBool "" True
                      Right _ -> assertFailure "no error"
                )
            Nothing -> assertBool "" True

parseFile :: Path Abs File -> IO (Either MegaparsecError InfoTable)
parseFile f = do
  let f' = toFilePath f
  s <- readFile f'
  return $ runParser f' s

doRun ::
  Handle ->
  InfoTable ->
  FunctionInfo ->
  IO (Either AsmError Val)
doRun hout tab funInfo = catchRunErrorIO (hRunCodeIO stdin hout tab funInfo)
