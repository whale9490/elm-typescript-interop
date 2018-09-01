module TypeScript.Generator exposing (elmModuleNamespace, generate, generatePort, generatePorts, prefix, wrapPorts)

import Result.Extra
import String.Interpolate
import TypeScript.Data.Aliases exposing (Aliases)
import TypeScript.Data.Port as Port
import TypeScript.Data.Program as Program exposing (Main)
import TypeScript.TypeGenerator exposing (toTsType)


generatePort : Aliases -> Port.Port -> Result String String
generatePort aliases (Port.Port name direction portType) =
    let
        inner =
            case direction of
                Port.Outbound ->
                    "subscribe(callback: (data: " ++ toTsType aliases portType ++ ") => void)"

                Port.Inbound ->
                    "send(data: " ++ toTsType aliases portType ++ ")"
    in
    String.Interpolate.interpolate
        """    {0}: {
      {1}: void
    }"""
        [ name, inner ]
        |> Ok


prefix : String
prefix =
    """// WARNING: Do not manually modify this file. It was generated using:
// https://github.com/dillonkearns/elm-typescript-interop
// Type definitions for Elm ports
export as namespace Elm"""


elmModuleNamespace : Aliases -> Main -> String
elmModuleNamespace aliases main =
    let
        fullscreenParam =
            main.flagsType
                |> Maybe.map (toTsType aliases)
                |> Maybe.map (\tsType -> "flags: " ++ tsType)
                |> Maybe.withDefault ""

        moduleName =
            String.join "." main.moduleName

        embedAppendParam =
            case main.flagsType of
                Nothing ->
                    ""

                Just flagsType ->
                    ", flags: " ++ toTsType aliases flagsType
    in
    "export namespace " ++ moduleName ++ """ {
  export function fullscreen(""" ++ fullscreenParam ++ """): App
  export function embed(node: HTMLElement | null""" ++ embedAppendParam ++ """): App
}"""


generatePorts : Aliases -> List Port.Port -> Result String String
generatePorts aliases ports =
    ports
        |> List.map (generatePort aliases)
        |> Result.Extra.combine
        |> Result.map (String.join "\n")
        |> Result.map wrapPorts


wrapPorts : String -> String
wrapPorts portsString =
    """
export interface App {
  ports: {
"""
        ++ portsString
        ++ """
  }
}
    """


generate : Program.Program -> Result String String
generate program =
    case program of
        Program.ElmProgram main aliases ports ->
            let
                generatePortsResult =
                    generatePorts aliases ports
            in
            Result.map
                (\generatedPorts ->
                    [ prefix
                    , generatedPorts
                    , elmModuleNamespace aliases main
                    ]
                        |> String.join "\n\n"
                )
                generatePortsResult
