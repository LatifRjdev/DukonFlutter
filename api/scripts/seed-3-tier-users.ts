import { PrismaClient } from '@prisma/client';
import * as bcrypt from 'bcrypt';

async function main() {
  const prisma = new PrismaClient();
  const tiers = [
    { tag: 'start',    phone: '+992910001001', name: 'QA START' },
    { tag: 'business', phone: '+992910001002', name: 'QA BUSINESS' },
    { tag: 'premium',  phone: '+992910001003', name: 'QA PREMIUM' },
  ];
  const password = await bcrypt.hash('qatest1234', 10);
  for (const t of tiers) {
    const user = await prisma.user.upsert({
      where: { phone: t.phone },
      update: { name: t.name, password },
      create: { phone: t.phone, name: t.name, password, isAdmin: false, isActive: true },
    });
    console.log(`${t.tag}: ${user.id}`);
  }
  await prisma.$disconnect();
}
main();
