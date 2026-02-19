import 'migration_export_downloader_stub.dart'
    if (dart.library.html) 'migration_export_downloader_web.dart';

void downloadMigrationExport(String filename, String content) {
  saveMigrationExportFile(filename, content);
}
