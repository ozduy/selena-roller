import AVFoundation
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Game sound mixes with the player's own music and stays quiet when the silent switch is on.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [])
        return true
    }

    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var game: GameViewController?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        let game = GameViewController()
        window.backgroundColor = GameViewController.backgroundColor
        window.rootViewController = game
        window.makeKeyAndVisible()
        self.window = window
        self.game = game
    }

    /// Notification Centre, Control Centre, Siri or a call: the game is still on screen, so pause the level here.
    /// (Going to the Home Screen also pauses it, from the page itself.)
    func sceneWillResignActive(_ scene: UIScene) {
        game?.pauseGame()
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        game?.reloadIfWaiting()
    }
}
