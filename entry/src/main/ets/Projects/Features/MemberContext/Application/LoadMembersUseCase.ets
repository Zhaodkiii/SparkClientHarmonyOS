import { DefaultMembersRepository } from '../Infrastructure/DefaultMembersRepository';
import { Member } from '../../../Core/Domain/Entities/Member';

export class LoadMembersUseCase {
  private readonly repository: DefaultMembersRepository;

  constructor(repository: DefaultMembersRepository) {
    this.repository = repository;
  }

  async execute(): Promise<Member[]> {
    return this.repository.loadMembers();
  }
}
