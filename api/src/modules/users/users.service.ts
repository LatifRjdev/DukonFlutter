import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ForbiddenException,
} from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../../prisma/prisma.service';
import { UpdateUserDto } from './dto/update-user.dto';

@Injectable()
export class UsersService {
  constructor(private prisma: PrismaService) {}

  async getProfile(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        phone: true,
        name: true,
        email: true,
        avatar: true,
        isAdmin: true,
        createdAt: true,
      },
    });

    if (!user) throw new NotFoundException('User not found');
    return user;
  }

  async updateProfile(userId: string, dto: UpdateUserDto) {
    return this.prisma.user.update({
      where: { id: userId },
      data: dto,
      select: {
        id: true,
        phone: true,
        name: true,
        email: true,
        avatar: true,
        isAdmin: true,
        createdAt: true,
      },
    });
  }

  async changePassword(
    userId: string,
    currentPassword: string,
    newPassword: string,
  ) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, password: true },
    });

    if (!user) throw new NotFoundException('User not found');

    const isMatch = await bcrypt.compare(currentPassword, user.password);
    if (!isMatch)
      throw new BadRequestException('Current password is incorrect');

    const hashedPassword = await bcrypt.hash(newPassword, 12);

    // F.1: bump tokensRevokedAt so any access token issued before
    // this moment is rejected by the JWT strategy. The user has to
    // log in again with the new password to get fresh tokens.
    await this.prisma.user.update({
      where: { id: userId },
      data: { password: hashedPassword, tokensRevokedAt: new Date() },
    });

    return { message: 'Password changed successfully' };
  }

  /**
   * Deletes the account and everything that cascades from it: the stores this
   * user owns, and every product, sale, customer and document beneath them.
   *
   * Refuses while an owned store still has other staff. Removing someone
   * else's workplace without warning is not a safe default, and the owner can
   * resolve it themselves by removing the staff or handing the store over.
   *
   * Wrong password raises 403, not 401 and not the 400 `changePassword` uses
   * for the same check. The client has to tell "you typed it wrong" apart from
   * "you still have staff", and the status code is the only signal it gets —
   * the exception's `message` is diagnostic and never reaches the UI.
   *
   * 401 is specifically wrong here even though "wrong password" sounds like it.
   * The mobile client's Dio interceptor treats any 401 as an expired access
   * token: it silently refreshes and REPLAYS the request. The refresh succeeds
   * (this user's session is perfectly valid — they just mistyped), so a typo
   * would fire a pointless second DELETE, and a refresh that happened to fail
   * would sign the user out for mistyping a password. 403 means "authenticated,
   * but this is refused", which is exactly the case, and no interceptor
   * touches it.
   */
  async deleteAccount(userId: string, password: string): Promise<void> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, password: true },
    });

    if (!user) throw new NotFoundException('User not found');

    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) throw new ForbiddenException('Password is incorrect');

    const blockingStaff = await this.prisma.staff.findFirst({
      where: {
        store: { ownerId: userId },
        userId: { not: userId },
        isActive: true,
      },
      select: { store: { select: { name: true } } },
    });

    if (blockingStaff) {
      throw new BadRequestException(
        `Store "${blockingStaff.store.name}" still has other staff. ` +
          'Remove them or transfer the store, then try again.',
      );
    }

    await this.prisma.user.delete({ where: { id: userId } });
  }
}
