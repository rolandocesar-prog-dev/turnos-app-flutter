/// Los flujos de Firestore no se reintentan: el SDK ya maneja la reconexión, y un error que llega
/// (permiso denegado, documento mal formado) no se arregla solo. Con el reintento automático de
/// Riverpod 3, en la app real el catálogo quedaba «cargando» sin mostrar el error (design.md §9).
Duration? noRetry(int retryCount, Object error) => null;
