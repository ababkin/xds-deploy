{-# LANGUAGE OverloadedStrings #-}

import Control.Applicative ((<$>))
import Data.Text (pack)
import qualified Data.Text as T
import Filesystem.Path (basename)
import Turtle
import Filesystem.Path.CurrentOS

apps = ["xds-downloader"]

dockerUser = "ababkin"
docker = "docker"
run = "run"
build = "build"
pull = "pull"
push = "push"

main :: IO ()
main = do
  curDir <- pwd
  appName <- encode . basename <$> pwd

  echo $ "detected current directory: " `T.append` appName

  buildDevImage appName
  copyExec curDir appName
  pullScratchImage
  buildDeployImage appName
  pushDeployImage appName


buildDevImage appName = 
  runCmd $ joinSpaces [docker, build, opts, "."] 
  where
    opts = joinSpaces [noRemove, targetOpt appName "development"]

copyExec curDir appName = 
    runCmd $ joinSpaces [docker, run, opts, remoteImageRepo appName "development", cmd] 
  where
    volumeMapping = encode curDir `T.append` "/deploy:/deploy"
    opts = joinSpaces [rmContainerOpt, volumeOpt volumeMapping]
    {- execPath = "/root/.cabal/bin/" `T.append` appName -}
    {- cmd = joinSpaces ["cp", execPath, "/deploy"] -}
    cmd = T.concat ["find dist -path '*/", appName, "/", appName, "' -exec cp {} /deploy ';'"]
    {- cmd = joinSpaces ["cp -r dist /deploy"] -}

pullScratchImage = 
  runCmd $ joinSpaces [docker, pull, remoteImageRepo "haskell-scratch" "integer-gmp"]

buildDeployImage appName = 
    runCmd $ joinSpaces [docker, build, opts, "."]
  where
    opts = joinSpaces [
        fileOpt "deploy/Dockerfile", 
        targetOpt appName "latest"
      ]

pushDeployImage appName = 
  runCmd $ joinSpaces [docker, push, remoteImageRepo appName "latest"]



-- options
noRemove = "--rm=false"
fileOpt = ("-f " `T.append`)
targetOpt name = ("-t " `T.append`) . remoteImageRepo name
rmContainerOpt = "--rm"
volumeOpt = ("-v " `T.append`)

remoteImageRepo name tag = T.concat [dockerUser, "/", name, ":", tag]

runCmd cmd = do
  print cmd
  print =<< shell cmd ""

joinSpaces = T.intercalate " "

