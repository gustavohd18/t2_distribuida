import 'dart:async';
import 'dart:io';

import 'dart:math';

import 'dart:typed_data';

class SuperNode {
  String name;
  //por enquanto deixar peers como string mas vai ser um separado
  List<String> peers;
  List<String> files;
  SuperNode(this.name);


void handleConnectionSocket(Socket client) {
  print('Connection from'
      ' ${client.remoteAddress.address}:${client.remotePort}');

  // listen for events from the client
  client.listen(
    // handle data from the client
    (Uint8List data) async {
      await Future.delayed(Duration(seconds: 1));
      final message = String.fromCharCodes(data);
      switch(message) { 
        case 'FILES': { 
          // o supernodo tem que mandar mensagem broadcast e trazer a lista de arquivos
            client.write('Solicitacao de arquivos atendidas');
        } 
        break; 
   
        default: { 
           client.write('Nada encontrado com essa solicitacao: ${message}');  
        }
        break; 
      } 
    },

    // handle errors
    onError: (error) {
      print(error);
      client.close();
    },

    // handle the client closing the connection
    onDone: () {
      print('Conexao encerrada supernodo caiu');
      client.close();
    },
  );
}

  Future<void> sendPackage() {
  InternetAddress multicastAddress = new InternetAddress('239.10.10.100');
  int multicastPort = 4545;
  Random rng = new Random();
  RawDatagramSocket.bind(InternetAddress.ANY_IP_V4, 0)
      .then((RawDatagramSocket s) {
    print("UDP Socket ready to send to group "
        "${multicastAddress.address}:${multicastPort}");

    new Timer.periodic(new Duration(seconds: 1), (Timer t) {
      //Send a random number out every second
      String msg = '${rng.nextInt(1000)}';
      stdout.write("Sending $msg  \r");
      s.send('$msg\n'.codeUnits, multicastAddress, multicastPort);
    });
  });
}
}
