module Main exposing (main)

import Browser
import Html exposing (Html, a, button, div, input, text)
import Html.Attributes exposing (href, placeholder, value)
import Html.Events exposing (onClick, onInput)
import Http
import Json.Decode exposing (Decoder, field, map3, string)
import Json.Encode as Encode


backend_url : String
backend_url =
    "http://localhost:8080"



-- MAIN


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }



-- MODEL


type alias Model =
    { keys : List String
    , url : String
    , status : Status
    }


type Status
    = Added Entry
    | Error Http.Error
    | None


init : () -> ( Model, Cmd Msg )
init _ =
    ( { keys = [], url = "", status = None }, Cmd.none )



-- UPDATE


type Msg
    = AddEntry String
    | GotData (Result Http.Error Entry)
    | UrlChanged String


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        AddEntry url ->
            ( model, makeAddEntryRequest url )

        GotData (Ok responseText) ->
            ( { model | status = Added responseText }
            , Cmd.none
            )

        GotData (Err e) ->
            ( { model | status = Error e }
            , Cmd.none
            )

        UrlChanged url ->
            ( { model | url = url }, Cmd.none )


type alias Entry =
    { key : String
    , long_url : String
    , short_url : String
    }


makeAddEntryRequest : String -> Cmd Msg
makeAddEntryRequest url =
    Http.post
        { url = backend_url
        , body = Http.jsonBody (Encode.object [ ( "url", Encode.string url ) ])
        , expect = Http.expectJson GotData entryDecoder
        }


entryDecoder : Decoder Entry
entryDecoder =
    map3 Entry
        (field "key" string)
        (field "long_url" string)
        (field "short_url" string)



-- VIEW


view : Model -> Html Msg
view model =
    div []
        [ input
            [ placeholder "enter the url"
            , value model.url
            , onInput UrlChanged
            ]
            []
        , button [ onClick (AddEntry model.url) ] [ text "add entry" ]
        , div [] [ viewStatus model.status ]
        ]


viewStatus : Status -> Html msg
viewStatus status =
    case status of
        Added entry ->
            div []
                [ div [] [ text ("Key: " ++ entry.key) ]
                , div [] [ text ("Original: " ++ entry.long_url) ]
                , div [] [ text "Short: ", a [ href entry.short_url ] [ text entry.short_url ] ]
                ]

        Error _ ->
            text "Failed to shorten URL"

        None ->
            text ""



-- SUBSCRIPTIONS (Required by Browser.element)


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none
