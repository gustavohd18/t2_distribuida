import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:t2_distribution_programming/client/MessageClient.dart';

class Client {
  final String id;
  final String ip;
  final int availablePort;
  List<String> files;
  final Socket socketClient;
  Client(this.id, this.socketClient, this.ip, this.availablePort);

  Future<void> listenerSupernodo() async {
    print('Conetado com o supernodo: ${socketClient.remoteAddress.address}:${socketClient.remotePort}');

    socketClient.listen(
      (Uint8List data) {
        //Precisa validar se é uma mensagem de texto ou sera um dado e mapear
        final serverResponse = String.fromCharCodes(data);
        print('supernodo: $serverResponse');
      },

      onError: (error) {
        print(error);
        socketClient.destroy();
      },

      onDone: () {
        print('Server left.');
        socketClient.destroy();
      },
    );
  }

  Future<void> sendMessageStringToSupernodo(MessageClient messageClient) async {
    //vamos usar json nos objetos para envio
    var encodedMessage = jsonEncode(messageClient);
    print('Nodo: $encodedMessage');
    socketClient.write(encodedMessage);
  }
}
