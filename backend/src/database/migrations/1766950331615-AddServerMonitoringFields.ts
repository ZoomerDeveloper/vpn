import { MigrationInterface, QueryRunner, TableColumn } from 'typeorm';

export class AddServerMonitoringFields1766950331615 implements MigrationInterface {
  public async up(queryRunner: QueryRunner): Promise<void> {
    // Добавляем новые поля в таблицу vpn_servers
    await queryRunner.addColumn(
      'vpn_servers',
      new TableColumn({
        name: 'ping',
        type: 'int',
        isNullable: true,
      }),
    );

    await queryRunner.addColumn(
      'vpn_servers',
      new TableColumn({
        name: 'lastHealthCheck',
        type: 'timestamp',
        isNullable: true,
      }),
    );

    await queryRunner.addColumn(
      'vpn_servers',
      new TableColumn({
        name: 'isHealthy',
        type: 'boolean',
        default: true,
      }),
    );

    await queryRunner.addColumn(
      'vpn_servers',
      new TableColumn({
        name: 'priority',
        type: 'int',
        default: 100,
      }),
    );

    await queryRunner.addColumn(
      'vpn_servers',
      new TableColumn({
        name: 'region',
        type: 'varchar',
        isNullable: true,
      }),
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    // Удаляем добавленные поля
    await queryRunner.dropColumn('vpn_servers', 'region');
    await queryRunner.dropColumn('vpn_servers', 'priority');
    await queryRunner.dropColumn('vpn_servers', 'isHealthy');
    await queryRunner.dropColumn('vpn_servers', 'lastHealthCheck');
    await queryRunner.dropColumn('vpn_servers', 'ping');
  }
}
