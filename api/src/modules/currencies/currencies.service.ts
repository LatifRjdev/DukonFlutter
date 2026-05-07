import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { PrismaService } from '../../prisma/prisma.service';
import { load } from 'cheerio';
import * as https from 'https';

const SUPPORTED_CURRENCIES = ['USD', 'RUB', 'EUR', 'CNY'];

interface NbtRate {
  currency: string;
  buyRate: number;
  sellRate: number;
  nbtRate: number;
}

@Injectable()
export class CurrenciesService {
  private readonly logger = new Logger(CurrenciesService.name);

  constructor(private prisma: PrismaService) {}

  /**
   * Fetch html from a URL using Node's built-in https module.
   * Avoids external HTTP client dependency in this module.
   *
   * F7.1: previously a non-200 status was silently coerced into an
   * unparseable HTML body that produced 0 rows; the call site then
   * returned [] with no diagnostic. Log the status + body length so
   * we can tell "fetch failed" from "table structure changed".
   */
  private fetchHtml(url: string): Promise<string> {
    return new Promise((resolve, reject) => {
      https
        .get(
          url,
          {
            // Some sites reject node's default UA. Pretend to be a real
            // browser so we get the same HTML the QA team sees.
            headers: {
              'User-Agent':
                'Mozilla/5.0 (compatible; DukonProBot/1.0; +https://dukonpro.tj)',
              Accept: 'text/html,application/xhtml+xml',
              'Accept-Language': 'en,ru;q=0.8,tg;q=0.6',
            },
          },
          (res) => {
            const status = res.statusCode || 0;
            let data = '';
            res.on('data', (chunk: string) => (data += chunk));
            res.on('end', () => {
              if (status < 200 || status >= 300) {
                this.logger.warn(
                  `nbt.tj returned HTTP ${status} for ${url} (body length ${data.length})`,
                );
                resolve('');
                return;
              }
              resolve(data);
            });
          },
        )
        .on('error', (err) => {
          this.logger.error(`fetch ${url} failed`, err);
          reject(err);
        });
    });
  }

  /**
   * Scrape nbt.tj for today's exchange rates and persist to DB.
   * Runs automatically every day at 09:00.
   */
  @Cron('0 9 * * *')
  async fetchRatesFromNbt(): Promise<NbtRate[]> {
    this.logger.log('Fetching exchange rates from nbt.tj...');

    try {
      const html = await this.fetchHtml('https://nbt.tj/en/');
      const $ = load(html);
      const today = new Date();
      today.setUTCHours(0, 0, 0, 0);

      const rates: NbtRate[] = [];

      // NBT table rows: currency code | buy | sell | nbt (official)
      // The site renders a table with class .exchange or similar.
      // We look for any <tr> that starts with a known currency code.
      $('table tr').each((_i, row) => {
        const cells = $(row).find('td');
        if (cells.length < 3) return;

        const code = $(cells[0]).text().trim().toUpperCase();
        if (!SUPPORTED_CURRENCIES.includes(code)) return;

        const parseNum = (el: ReturnType<typeof $>) =>
          parseFloat(el.text().replace(/\s/g, '').replace(',', '.')) || 0;

        const nbtRate = parseNum($(cells[1]));
        // Some NBT pages show only nbt rate; buy/sell may differ slightly
        const buyRate =
          cells.length >= 3 ? parseNum($(cells[2])) : nbtRate * 0.998;
        const sellRate =
          cells.length >= 4 ? parseNum($(cells[3])) : nbtRate * 1.002;

        rates.push({ currency: code, buyRate, sellRate, nbtRate });
      });

      if (rates.length === 0) {
        // F7.1: surface enough context to diagnose without re-running.
        // Most likely causes: site moved the table, returned a JS-only
        // shell, or the request was blocked by Cloudflare and HTML is
        // a challenge page. Body length is a quick signal.
        const tableCount = $('table').length;
        const trCount = $('table tr').length;
        this.logger.warn(
          `No currency rates parsed from nbt.tj — html bytes=${html.length}, tables=${tableCount}, trs=${trCount}. ` +
            `Page structure may have changed; consider switching to https://nbt.tj/ru/kurs/kurs.php or the official XML feed.`,
        );
        return [];
      }

      // Upsert each rate
      await Promise.all(
        rates.map((r) =>
          this.prisma.currencyRate.upsert({
            where: { currency_date: { currency: r.currency, date: today } },
            update: {
              buyRate: r.buyRate,
              sellRate: r.sellRate,
              nbtRate: r.nbtRate,
            },
            create: {
              currency: r.currency,
              buyRate: r.buyRate,
              sellRate: r.sellRate,
              nbtRate: r.nbtRate,
              date: today,
            },
          }),
        ),
      );

      this.logger.log(
        `Saved ${rates.length} currency rates for ${today.toISOString().slice(0, 10)}`,
      );
      return rates;
    } catch (err) {
      this.logger.error('Failed to fetch rates from nbt.tj', err);
      return [];
    }
  }

  /** Return the most recent rate record for each supported currency. */
  async getLatestRates() {
    const latest = await this.prisma.currencyRate.findMany({
      orderBy: { date: 'desc' },
      distinct: ['currency'],
    });
    return latest;
  }

  /** Return rate history for a given currency over the last N days. */
  async getRateHistory(currency: string, days: number) {
    const since = new Date();
    since.setDate(since.getDate() - days);
    since.setUTCHours(0, 0, 0, 0);

    return this.prisma.currencyRate.findMany({
      where: {
        currency: currency.toUpperCase(),
        date: { gte: since },
      },
      orderBy: { date: 'asc' },
    });
  }
}
