*quiero desarrollar PlebsHub, app completa para:*
- cliente nostr
- wallet non-custodial
- cliente bitchat
- player de musica
- player de video
- Spot Trading
- Marketplace
- Cliente Bittorrent
- Integración Tor

*primera etapa:*
- La UI debe ser micro-diseñada, o sea, el diseño debe ser excepciónal, casi "pulida" pixel por pixel (como las apps de Macos/iOS)
- cliente de nostr con una interfaz similar a la de X/Twitter
- puedes usar como referencia: https://cdn.dribbble.com/userupload/12122028/file/original-5665fb3befcf6a3dd710d65a482b0656.png?resize=1504x1128&vertical=center (pero NO INCLUYAS EL NOMBRE KILOGRAM, somos PlebsHub)
- el cliente debe tener distintas visualizaciónes: Single Column, Multi Column (como Tweetdeck)
- desde día uno Multiplataforma: Android, iOS, Macos, Windows, Linux y WEB (esta versión puede ser más limitada)!
- como nostr es un sistema de documentos, quiero utilizarlo para usarlo como un IRC (Chat), con canales públicos y privados
- TODA publicación de un usuario debe ser ZAPEABLE, absolutamente todo, Zap es la "currency" dentro de la app

*plan a futuro (segunda etapa):*
- nostr soporta zaps, por lo que para integrar esto quiero usar Breez para crear wallets completas non-custodial o poder conectar la app a una cuenta externa para recibir/enviar zaps
- Multi/Publicación, integrar otras RRSS para que a través de la app publique automáticamente en esas otras redes (Post en Nostr -> Post en X, Facebook, etc)
- Cliente de Trading completo: Gráfico OHLC (usando precios de Bincance u otro) con ordenes spot, pudiendo incluir Trailing Stop, Take Profit, Stop Loss. Solo BTC/USD

*funciones extras (tercera etapa):*
- Mercado P2P de "Pleb-to-Pleb" (Venta de Sats por CLP): Binance y otros tienen un sistema en donde alguien quiere comprar algún tipo de activo, el que vende "ofrece" a un precio X, el comprador Transfiere al vendedor, carga el comprobante de pago y "confirma" su pago, luego el vendedor aprueba que recibió los fondos y ahí libera el pago y transfiere. Quizás con una mezcla con nostr se podría desarrollar este sistema
- Nostr "Marketplace" de Servicios Locales: Un espacio donde "plebeyos" ofrezcan servicios (clases, diseño, gasfitería) pagados en BTC.
- Inteligencia Artificial "Pleb-Side": Integrar TradingBot (otro desarrollo mio) con el sistema para enviar señales
- Cliente de Bittorrent incentivado con Zaps, si alguien seedea un torrent, los mismos usuarios le pueden "pagar" por compartirlo (manual) y también se envían micro-zaps automáticos de usuarios que lo descarguen

*integración (cuarta etapa):*
- integrar con bitchat (bluetooth mesh), esta parte se usan los canales georeferenciados para integrar con el sistema chat. No implementar esta parte aun, ya que tenemos bitchat-flutter (/Users/avillagran/Desarrollo/bitchat-flutter) que aun está en desarrollo, para luego usarlo como una lib
- Integración con PlebsPlayer para Player Video, Audio y cliente de Bittorrent, para que tengas referencia, está en desarrollo y luego hay que usarlo como lib /Users/avillagran/Desarrollo/PlebsPlayer/PlebsPlayerOSS

