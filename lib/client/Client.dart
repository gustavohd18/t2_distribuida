import 'dart:io';

import 'dart:typed_data';

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

  Future<void> sendMessageStringToSupernodo(String message) async {
    print('Nodo: $message');
    socketClient.write(message);
  }
}
