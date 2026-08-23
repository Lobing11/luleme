/**
 * 鹿了么 - 记录数据仓库（RelationalStore / SQLite）
 *
 * 所有数据仅保存在本机应用沙箱内，模块不申请任何网络权限。
 */
import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Record } from '../model/RecordModel';

const STORE_CONFIG: relationalStore.StoreConfig = {
  name: 'luleme.db',
  securityLevel: relationalStore.SecurityLevel.S1
};

const CREATE_TABLE_SQL: string = `CREATE TABLE IF NOT EXISTS records (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  timestamp INTEGER NOT NULL,
  mood INTEGER NOT NULL,
  note TEXT NOT NULL
)`;

export class RecordRepository {
  private static instance: RecordRepository | null = null;
  private store: relationalStore.RdbStore | null = null;

  static getInstance(): RecordRepository {
    if (RecordRepository.instance === null) {
      RecordRepository.instance = new RecordRepository();
    }
    return RecordRepository.instance;
  }

  /** 初始化数据库（幂等），必须在首次读写前调用 */
  async init(context: common.Context): Promise<void> {
    if (this.store !== null) {
      return;
    }
    const store = await relationalStore.getRdbStore(context, STORE_CONFIG);
    await store.executeSql(CREATE_TABLE_SQL);
    this.store = store;
  }

  private requireStore(): relationalStore.RdbStore {
    if (this.store === null) {
      throw new Error('RecordRepository not initialized');
    }
    return this.store;
  }

  /** 新增记录，返回新记录的 id */
  async add(timestamp: number, mood: number, note: string): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      'timestamp': timestamp,
      'mood': mood,
      'note': note
    };
    return await this.requireStore().insert('records', values);
  }

  /** 更新记录 */
  async update(id: number, timestamp: number, mood: number, note: string): Promise<void> {
    const values: relationalStore.ValuesBucket = {
      'timestamp': timestamp,
      'mood': mood,
      'note': note
    };
    const predicates = new relationalStore.RdbPredicates('records');
    predicates.equalTo('id', id);
    await this.requireStore().update(values, predicates);
  }

  /** 删除记录 */
  async remove(id: number): Promise<void> {
    const predicates = new relationalStore.RdbPredicates('records');
    predicates.equalTo('id', id);
    await this.requireStore().delete(predicates);
  }

  /** 清空全部记录 */
  async clearAll(): Promise<void> {
    await this.requireStore().executeSql('DELETE FROM records');
  }

  /** 全部记录（按时间降序） */
  async getAll(): Promise<Record[]> {
    const resultSet = await this.requireStore().querySql(
      'SELECT id, timestamp, mood, note FROM records ORDER BY timestamp DESC');
    return this.readResultSet(resultSet);
  }

  /** 按 id 查询单条记录 */
  async getById(id: number): Promise<Record | null> {
    const resultSet = await this.requireStore().querySql(
      'SELECT id, timestamp, mood, note FROM records WHERE id = ?', [id]);
    const list = this.readResultSet(resultSet);
    if (list.length === 0) {
      return null;
    }
    return list[0];
  }

  private readResultSet(resultSet: relationalStore.ResultSet): Record[] {
    const list: Record[] = [];
    try {
      while (resultSet.goToNextRow()) {
        const record: Record = {
          id: resultSet.getLong(resultSet.getColumnIndex('id')),
          timestamp: resultSet.getLong(resultSet.getColumnIndex('timestamp')),
          mood: resultSet.getLong(resultSet.getColumnIndex('mood')),
          note: resultSet.getString(resultSet.getColumnIndex('note'))
        };
        list.push(record);
      }
    } finally {
      resultSet.close();
    }
    return list;
  }
}
