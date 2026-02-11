import { promises as fs } from "node:fs";
import path from "node:path";
import { randomUUID } from "node:crypto";
import {
  S3Client,
  PutObjectCommand,
  GetObjectCommand
} from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
import { getConfig } from "../config.js";

export interface StoragePutResult {
  key: string;
}

export interface StorageProvider {
  putObject(key: string, bytes: Buffer, contentType: string): Promise<StoragePutResult>;
  getSignedUrl(key: string): Promise<string>;
  getObject?(key: string): Promise<Buffer>;
}

class LocalStorageProvider implements StorageProvider {
  private readonly baseDir: string;

  constructor(baseDir: string) {
    this.baseDir = baseDir;
  }

  async putObject(key: string, bytes: Buffer): Promise<StoragePutResult> {
    const finalKey = key || randomUUID();
    const fullPath = path.join(this.baseDir, finalKey);
    await fs.mkdir(path.dirname(fullPath), { recursive: true });
    await fs.writeFile(fullPath, bytes);
    return { key: finalKey };
  }

  async getSignedUrl(key: string): Promise<string> {
    const config = getConfig();
    return `${config.API_BASE_URL}/v1/storage/local/${encodeURIComponent(key)}`;
  }

  async getObject(key: string): Promise<Buffer> {
    const fullPath = path.join(this.baseDir, key);
    return fs.readFile(fullPath);
  }
}

class S3StorageProvider implements StorageProvider {
  private readonly client: S3Client;
  private readonly bucket: string;
  private readonly urlTtlSeconds: number;

  constructor(client: S3Client, bucket: string, urlTtlSeconds: number) {
    this.client = client;
    this.bucket = bucket;
    this.urlTtlSeconds = urlTtlSeconds;
  }

  async putObject(key: string, bytes: Buffer, contentType: string): Promise<StoragePutResult> {
    await this.client.send(
      new PutObjectCommand({
        Bucket: this.bucket,
        Key: key,
        Body: bytes,
        ContentType: contentType
      })
    );
    return { key };
  }

  async getSignedUrl(key: string): Promise<string> {
    const command = new GetObjectCommand({
      Bucket: this.bucket,
      Key: key
    });
    return getSignedUrl(this.client, command, {
      expiresIn: this.urlTtlSeconds
    });
  }
}

export const buildStorageProvider = (): StorageProvider => {
  const config = getConfig();

  if (config.STORAGE_PROVIDER === "s3") {
    const client = new S3Client({
      region: config.S3_REGION,
      endpoint: config.S3_ENDPOINT,
      forcePathStyle: config.S3_FORCE_PATH_STYLE,
      credentials:
        config.S3_ACCESS_KEY && config.S3_SECRET_KEY
          ? {
              accessKeyId: config.S3_ACCESS_KEY,
              secretAccessKey: config.S3_SECRET_KEY
            }
          : undefined
    });

    return new S3StorageProvider(
      client,
      config.S3_BUCKET,
      config.RECEIPT_URL_TTL_SECONDS
    );
  }

  return new LocalStorageProvider(path.resolve("services/api/.tmp/storage"));
};
