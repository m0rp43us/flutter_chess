import 'package:chess_bot/chess_board/chess.dart';
import 'package:chess_bot/chess_control/chess_controller.dart';
import 'package:chess_bot/util/utils.dart';
import 'package:chess_bot/util/widget_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../main.dart';

String _createGameCode() {
  final availableChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
      .runes
      .map((int rune) => String.fromCharCode(rune))
      .toList();
  String out = '';
  for (int i = 0; i < 6; i++)
    out += availableChars[random.nextInt(availableChars.length)];
  return out;
}

String _currentGameCode;

String joinGameCodeWithoutFirebaseCreation({String gameCode}) {
  if (gameCode != null)
    return _currentGameCode = gameCode;
  else
    return _currentGameCode = _createGameCode();
}

DocumentReference get currentGameDoc {
  if (inOnlineGame)
    return FirebaseFirestore.instance.collection('games').doc(_currentGameCode);
  else
    return null;
}

String get currentGameCode {
  return _currentGameCode == null ? strings.local : _currentGameCode;
}

bool get inOnlineGame {
  return _currentGameCode != null;
}

class OnlineGameController {
  final ChessController _chessController;
  Function update;

  OnlineGameController(this._chessController);

  void finallyCreateGameCode() {
    //create new game id locally
    String gameId = joinGameCodeWithoutFirebaseCreation();
    //create the bucket in cloud firestore
    //set the local bot disabled etc
    _chessController.botBattle = false;
    prefs.setBool('bot', false);
    prefs.setBool('botbattle', false);
    //reset the local game
    _chessController.controller.resetBoard();
    //new game map
    Map<String, dynamic> game = {};
    game['white'] = uuid;
    game['black'] = null;
    game['fen'] = _chessController.game.fen;
    game['moveFrom'] = null;
    game['moveTo'] = null;
    game['id'] = gameId;
    //white towards user
    _chessController.whiteSideTowardsUser = true;
    prefs.setBool('whiteSideTowardsUser', true);
    //upload to firebase
    currentGameDoc.set(game);
    //lock listener
    lockListener();
    //update views
    update();
  }

  //join and init the game code
  void joinGame(String code) {
    //create the game locally
    joinGameCodeWithoutFirebaseCreation(gameCode: code.toUpperCase());
    //check if the code exists
    currentGameDoc.get().then((event) {
      //check if doc exists and white is not already this user
      if (event.exists && (event.get('white') != uuid)) {
        //reset the local
        _chessController.resetBoard();
        //set the local bot disabled etc
        _chessController.botBattle = false;
        prefs.setBool('bot', false);
        prefs.setBool('botbattle', false);
        //set the black id
        currentGameDoc.update(<String, dynamic>{'black': uuid});
        //black towards user
        _chessController.whiteSideTowardsUser = false;
        prefs.setBool('whiteSideTowardsUser', false);
        //lock the listener since the game exists
        lockListener();
        //update
        update();
      } else {
        //game code is null then, inform user
        _currentGameCode = null;
        showAnimatedDialog(
            icon: Icons.warning,
            title: strings.warning,
            text: strings.game_id_not_found);
      }
    });
  }

  //leave the online game / set the code to null then update views
  void leaveGame() {
    _currentGameCode = null;
    update();
  }

  void lockListener() {
    currentGameDoc.snapshots().listen((event) {
      //if the doc does not exist, set game code to null
      if (!event.exists) {
        _currentGameCode = null;
        return;
      }
      //only update if the listener is sure that this is not an old game code
      //and the data are not null
      if (event.data() != null && (event.get('id') == _currentGameCode)) {
        //update complete game
        _chessController.game = Chess.fromFEN(event.get('fen'));
        ChessController.moveFrom = event.get('moveFrom');
        ChessController.moveTo = event.get('moveTo');
        //update all views
        update();
      }
    });
  }
}
