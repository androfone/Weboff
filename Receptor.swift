import SwiftUI
import AVFoundation
import Network

class RadioReceiver: ObservableObject {
    var audioPlayer: AVAudioPlayer?
    var listener: NWListener?
    @Published var selectedChannel: Int = 1
    var multicastGroup: NWEndpoint.Host
    var port: NWEndpoint.Port

    init(multicastGroup: String, port: UInt16) {
        self.multicastGroup = NWEndpoint.Host(multicastGroup)
        self.port = NWEndpoint.Port(rawValue: port) ?? 12345
        startListening()
    }

    func startListening() {
        do {
            let parameters = NWParameters.udp
            parameters.allowLocalEndpointReuse = true
            listener = try NWListener(using: parameters, on: port)
            listener?.newConnectionHandler = { [weak self] connection in
                connection.start(queue: .main)
                self?.receiveAudio(from: connection)
            }
            listener?.start(queue: .main)
        } catch {
            print("Erro ao iniciar listener: \(error)")
        }
    }

    func receiveAudio(from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1024) { [weak self] data, context, isComplete, error in
            if let data = data, !data.isEmpty {
                self?.filterAndPlayAudio(data)
            }
            if isComplete {
                connection.cancel()
            } else {
                self?.receiveAudio(from: connection)
            }
        }
    }

    func filterAndPlayAudio(_ data: Data) {
        let channelIdentifier = data.first ?? 0
        if Int(channelIdentifier) == selectedChannel {
            let audioData = data.subdata(in: 1..<data.count)
            playAudio(audioData)
        }
    }

    func playAudio(_ data: Data) {
        do {
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.play()
        } catch {
            print("Erro ao reproduzir áudio: \(error)")
        }
    }
}

struct RadioReceiverView: View {
    @ObservedObject var radioReceiver: RadioReceiver

    var body: some View {
        VStack {
            Text("ProCampus FM")
                .font(.custom("NoteWorthy", size: 34))
                .foregroundColor(.blue)
                .padding()

            Spacer()

            if radioReceiver.audioPlayer?.isPlaying == true {
                Text("Reproduzindo Ao Vivo...")
                    .font(.custom("NoteWorthy", size: 20))
                    .foregroundColor(.blue)
                    .padding()
            } else {
                Text("Aguardando Transmissão")
                    .font(.custom("NoteWorthy", size: 20))
                    .foregroundColor(.blue)
                    .padding()
            }

            Spacer()
        }
        .padding()
    }
}
