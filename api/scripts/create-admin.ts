import { PrismaClient } from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();

async function main() {
  const phone = process.argv[2] || '+992000000000';
  const password = process.argv[3] || 'admin123';
  const name = process.argv[4] || 'Admin';

  const hashedPassword = await bcrypt.hash(password, 10);

  const user = await prisma.user.upsert({
    where: { phone },
    update: { isAdmin: true },
    create: {
      phone,
      password: hashedPassword,
      name,
      isAdmin: true,
    },
  });

  console.log(
    `Admin user created/updated: ${user.name} (${user.phone}), isAdmin=${user.isAdmin}`,
  );
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
