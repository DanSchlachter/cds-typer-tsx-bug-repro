using { repro } from '../db/schema';

service ReproService @(path: '/api') {
  entity Files as projection on repro.Files;
}
